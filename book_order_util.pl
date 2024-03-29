#!/usr/bin/perl

use lib '.';
use BookPageOrder;
use JSON;
use PDF::API2;
use Getopt::Std;
use Data::Dumper;
use Digest::CRC qw(crc32);

getopts('itc1ds:');

my $data = BookPageOrder::order(@ARGV);

if ($opt_t || $opt_i) {
    # see https://metacpan.org/pod/PDF::API2::Page for page sizes
    #   e.g. 'A4' or '11x8.5'
    my $pdfPageSize = $opt_s || 'letter';

    my $pdf = PDF::API2->new();
    my @dt = localtime;
    $pdf->producer('BookPageOrder v' . $BookPageOrder::VERSION);
    $pdf->creator(to_json($data));
    my $pdfdate = sprintf('D:%04d%02d%02d%02d%02d', 1900 + $dt[5], $dt[4] + 1, $dt[3], $dt[2], $dt[1], $dt[0]);
    $pdf->created($pdfdate);
    $pdf->modified($pdfdate);

    if ($opt_t) {
        &test_pdf($pdf, $data, $pdfPageSize);
    } else {
        &instructions_pdf($pdf, $data, $pdfPageSize);
    }


} elsif ($opt_d) {
    print to_json($data, {pretty=>1});

} else {
    my @ord = @{$data->{order}};
    if ($opt_1) {
        foreach (@ord) {
            $_++;
        }
    }
    if ($opt_c) {
        print join(", ", @ord) . "\n";
    } else {
        print join("\n", @ord) . "\n";
    }
}



sub instructions_pdf {
    my ($pdf, $data, $pdfPageSize) = @_;
    my $usesSignatures = scalar(@{$data->{signatureSizes}}) > 1;

    my $page = $pdf->page();
    $page->size($pdfPageSize);
    my $txt = $page->text();
    my $gfx = $page->graphics();
    my $font = $pdf->font('Helvetica');
    my $fontBold = $pdf->font('Helvetica-Bold');

    my $source = PDF::API2->open('scissors.pdf');
    my $scissors = $pdf->embed_page($source, 1);
    $source = PDF::API2->open('fold.pdf');
    my $fold = $pdf->embed_page($source, 1);


    my @bounds = $page->size();
    my $pw = $bounds[2] - $bounds[0];
    my $ph = $bounds[3] - $bounds[1];
    my $subw = $pw / $data->{numAcross};
    my $subh = $ph / $data->{numDown};
    my $fontScale = $subw / 150;

    # cut lines
    my $x = $subw * 2;
    $gfx->line_width(1);
    $gfx->stroke_color('#AAAAAA');
    $gfx->line_dash_pattern(10);
    for (my $i = 0 ; $i < $data->{numAcross} / 2 - 1 ; $i++) {
        $gfx->move($x, 0);
        $gfx->vline($ph);
        $gfx->stroke();
        $gfx->save;
        $gfx->transform(-translate=>[$x + 13,10], -rotate=>90);
        $gfx->object($scissors, 0, 0, 0.7, 0.7);
        $gfx->restore;
        $x += $subw * 2;
    }
    my $y = $subh;
    for (my $i = 0 ; $i < $data->{numDown} - 1 ; $i++) {
        $gfx->move(0, $y);
        $gfx->hline($pw);
        $gfx->stroke();
        $gfx->object($scissors, 10, $y - 13, 0.7, 0.7);
        $y += $subh;
    }

    # fold lines
    $gfx->line_width(0.6);
    $gfx->stroke_color('#DDDDDD');
    $gfx->line_dash_pattern();
    $x = $subw;
    for (my $i = 0 ; $i < $data->{numAcross} - 1 ; $i++) {
        $gfx->move($x, 0);
        $gfx->vline($ph);
        $gfx->stroke();
        $gfx->object($fold, $x - 23, $ph - 30, 0.2, 0.2);
        $x += $subw * 2;
    }

    my $tileLetter = 'A';
    my $lastTileLetter;
    for (my $y = 0 ; $y < $data->{numDown} ; $y++) {
        for (my $x = 0 ; $x < $data->{numAcross} ; $x++) {
            my $i = $y * $data->{numAcross} + $x + $pg * $data->{perSheet} / 2;
            my $origx = $x * $subw;
            my $origy = $ph - ($y + 1) * $subh;

            my $fsize = 70 * $fontScale;
            $txt->font($fontBold, $fsize);
            $txt->fill_color('#CCCCCC');
            if ($x % 2 == 0) {
                $txt->translate($origx + $subw, $origy + $subh * 0.4);
                $txt->text($tileLetter, (align=>'center'));
                $lastTileLetter = $tileLetter;
                $tileLetter++;
            }
        }
    }

    $pdf->save('/dev/stdout');
}

sub test_pdf {
    my ($pdf, $data, $pdfPageSize) = @_;
    my $usesSignatures = scalar(@{$data->{signatureSizes}}) > 1;

    my $ctx = Digest::CRC->new(type=>'crc32');
    $ctx->add(join(':', $data->{numPages}, $data->{numAcross}, $data->{numDown}, ($usesSignatures ? $data->{signatureSize} : 0)));
    my $hash = $ctx->hexdigest;
    $pdf->title("BookPageOrder Test Page $hash");
    $pdf->subject($hash);
    my @dt = localtime;
    my $timestamp = sprintf('%04d-%02d-%02dT%02d:%02d:%02d', 1900 + $dt[5], $dt[4] + 1, $dt[3], $dt[2], $dt[1], $dt[0]);

    for (my $pg = 0 ; $pg < $data->{numSheets} * 2 ; $pg++) {
        my $page = $pdf->page();
        $page->size($pdfPageSize);
        my $txt = $page->text();
        my $gfx = $page->graphics();
        my $font = $pdf->font('Helvetica');
        my $fontBold = $pdf->font('Helvetica-Bold');

        my @bounds = $page->size();
        my $pw = $bounds[2] - $bounds[0];
        my $ph = $bounds[3] - $bounds[1];

        my $subw = $pw / $data->{numAcross};
        my $subh = $ph / $data->{numDown};
        my $fontScale = $subw / 150;

        # cut lines
        my $x = $subw * 2;
        $gfx->line_width(1);
        $gfx->stroke_color('#AAAAAA');
        $gfx->line_dash_pattern(10);
        for (my $i = 0 ; $i < $data->{numAcross} / 2 - 1 ; $i++) {
            $gfx->move($x, 0);
            $gfx->vline($ph);
            $gfx->stroke();
            $gfx->close();
            $x += $subw * 2;
        }
        my $y = $subh;
        for (my $i = 0 ; $i < $data->{numDown} - 1 ; $i++) {
            $gfx->move(0, $y);
            $gfx->hline($pw);
            $gfx->stroke();
            $gfx->close();
            $y += $subh;
        }

        # fold lines
        $gfx->line_width(0.6);
        $gfx->stroke_color('#DDDDDD');
        $gfx->line_dash_pattern();
        $x = $subw;
        for (my $i = 0 ; $i < $data->{numAcross} - 1 ; $i++) {
            $gfx->move($x, 0);
            $gfx->vline($ph);
            $gfx->stroke();
            $gfx->close();
            $x += $subw * 2;
        }

        # for every page
        for (my $y = 0 ; $y < $data->{numDown} ; $y++) {
            for (my $x = 0 ; $x < $data->{numAcross} ; $x++) {
                my $i = $y * $data->{numAcross} + $x + $pg * $data->{perSheet} / 2;
                my $origx = $x * $subw;
                my $origy = $ph - ($y + 1) * $subh;
                #warn "( [$y,$x] " . ($origx + $subw / 2) . "," . ($origy + $subh / 5) . ")\n";

                # big page number
                my $fsize = 80 * $fontScale;
                $txt->font($fontBold, $fsize);
                $txt->fill_color('#E0E0E0');
                $txt->translate($origx + $subw / 2, $origy + $subh / 3);
                $txt->text($data->{order}->[$i], (align=>'center'));

                # header
                my $fsize = 8 * $fontScale;
                $txt->font($font, $fsize);
                $txt->fill_color('#AAAAAA');
                $txt->translate($origx + 13, $origy + $subh - $fsize * 1.8);
                $txt->text($hash . ' - ' . $timestamp);

                # footer
                my $sigStart = 0;
                my $footer = sprintf('sheet %d, side %s', $pg / 2, ($pg % 2 ? 'B' : 'F'));
                if ($usesSignatures) {
                    my ($sigNum, $sigPg) = &findSig($data->{order}->[$i], $data);
                    $footer .= sprintf(', sig %d, sigPg %d', $sigNum, $sigPg);
                    $sigStart = ($sigPg == 0);
                }
                $txt->fill_color('#777777');
                $txt->translate($origx + 13, $origy + 16);
                $txt->text($footer);

                # denote start of signature
                if ($sigStart) {
                    $gfx->line_width(2);
                    $gfx->stroke_color('#444444');
                    $gfx->rectangle($origx - $subw + 5, $origy + 5, $origx + $subw - 5, $origy + $subh - 5);
                    $gfx->stroke();
                    $gfx->close();
                }

                # stack center
                if ($x % 2 == 0) {
                    my $fsize = 11 * $fontScale;
                    $txt->font($fontBold, $fsize);
                    $txt->translate($origx + $subw, $origy + $subh / 2);
                    my $snum = $y * $data->{numAcross} / 2 + $x / 2;
                    $snum = $y * $data->{numAcross} / 2 + $data->{numAcross} / 2 - $x / 2 - 1 if ($pg % 2);
                    $txt->text(sprintf('stack %d', $snum), (align=>'center'));
                    $txt->translate($origx + $subw, $origy + $subh / 2 - $fsize * 1.2);
                    $txt->text(sprintf('(%d/%d, %d)', $x, $x + 1, $y), (align=>'center'));
                }

                # back cover
                if ($data->{order}->[$i] == $data->{numPagesActual} - 1) {
                    my $image = $pdf->image('qrcode.png');
                    my $dim = 40 * $fontScale;
                    $gfx->object($image, $origx + 10, $origy + $subh - 1.5 * $dim, $dim, $dim);
                    $txt->font($fontBold, $fsize);
                    $txt->translate($origx + 13, $origy + $fsize * 5);
                    $txt->text('BookPageOrder v' . $BookPageOrder::VERSION);
                    $txt->font($font, $fsize * 0.8);
                    $txt->translate($origx + 13, $origy + $fsize * 4);
                    $txt->text('github.com/naknomum/BookPageOrder');
                }
            }
        }

        if ($pg == 0) {
            my @stats = qw(numPages numPagesActual numAcross numDown perSheet numSheets);
            if ($usesSignatures) {
                push(@stats, 'signatureSize');
            } else {
                push(@stats, 'uses signatures');
                $data->{'uses signatures'} = 'no';
            }
            my $fsize = 10 * $fontScale;
            my $x = $subw * 1.7;
            my $y = $ph - $fsize * 4;
            $txt->fill_color('#444444');
            foreach my $s (@stats) {
                $txt->translate($x - 3, $y);
                $txt->font($font, $fsize);
                $txt->text($s, (align=>'right'));
                $txt->translate($x + 3, $y);
                $txt->font($fontBold, $fsize);
                $txt->text($data->{$s}, (align=>'left'));
                $y -= $fsize * 1.3;
            }

            # rulers to measure unprintable margin (for safeMargin)
            $txt->font($font, 6);
            my $tickSize = 10;  # really half of it
            $gfx->line_width(1);
            $gfx->stroke_color('#000000');
            for (my $i = 0 ; $i < 7 ; $i++) {
                $gfx->move(5 + $i * 5, $ph / 2 + $tickSize);
                $gfx->vline($ph / 2 - $tickSize);
                $gfx->move($pw - (5 + $i * 5), $ph / 2 + $tickSize);
                $gfx->vline($ph / 2 - $tickSize);
                $gfx->move(0, $ph / 2);
                $gfx->hline(35);
                $gfx->move($pw / 2, 0);
                $gfx->vline(35);

                $gfx->move($pw / 2 + $tickSize, 5 + $i * 5);
                $gfx->hline($pw / 2 - $tickSize);
                $gfx->move($pw / 2 + $tickSize, $ph - (5 + $i * 5));
                $gfx->hline($pw / 2 - $tickSize);
                $gfx->move($pw, $ph / 2);
                $gfx->hline($pw - 35);
                $gfx->stroke();
                $gfx->close();
                $gfx->move($pw / 2, $ph);
                $gfx->vline($ph - 35);

                if ($i % 2) {
                    $txt->translate(5 + $i * 5, $ph / 2 + 12);
                    $txt->text(5 + $i * 5, (align=>'center'));
                    $txt->translate($pw - (5 + $i * 5), $ph / 2 + 12);
                    $txt->text(5 + $i * 5, (align=>'center'));
                    $txt->translate($pw / 2 - 12, 3 + $i * 5);
                    $txt->text(5 + $i * 5, (align=>'right'));
                    $txt->translate($pw / 2 - 12, $ph - (7 + $i * 5));
                    $txt->text(5 + $i * 5, (align=>'right'));
                } else {
                    $txt->translate(5 + $i * 5, $ph / 2 - 16);
                    $txt->text(5 + $i * 5, (align=>'center'));
                    $txt->translate($pw - (5 + $i * 5), $ph / 2 - 16);
                    $txt->text(5 + $i * 5, (align=>'center'));
                    $txt->translate($pw / 2 + 12, 3 + $i * 5);
                    $txt->text(5 + $i * 5, (align=>'left'));
                    $txt->translate($pw / 2 + 12, $ph - (7 + $i * 5));
                    $txt->text(5 + $i * 5, (align=>'left'));
                }
            }
        }

    }
    $pdf->save('/dev/stdout');
}


sub findSig {
    my ($num, $data) = @_;
    my $in = -1;
    for (my $i = 0 ; $i < scalar(@{$data->{stack}}) ; $i++) {
        if (grep(/^$num$/, @{$data->{stack}->[$i]})) {
            $in = int($i / $data->{signatureSize});
            break;
        }
    }
    die "could not findSig num=$num" unless ($in >= 0);
    return ($in, $num % ($data->{signatureSize} * 4));
}

