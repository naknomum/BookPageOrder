package BookPageOrder;


# when debug is on, the json output will have strings rather than numbers  :(
#   it is related to this:  https://stackoverflow.com/a/16864305
my $debug = 0;

use POSIX ceil;
use Data::Dumper;
use JSON;
our $VERSION = '0.91';


sub order {
    my ($numPages, $numAcross, $numDown, $signatureSize) = @_;
    die "must have numPages" unless $numPages;
    $numPages = int($numPages);

    # defaults to 2 across, 1 down
    $numAcross = int($numAcross || 2);
    $numDown = int($numDown || 1);
    die "numAcross must be even" unless ($numAcross % 2 == 0);

    my $perSheet = 2 * $numAcross * $numDown;
    my $numSheets = ceil($numPages / $perSheet);
    my $numPagesActual = $numSheets * $perSheet;
    $signatureSize = $numPagesActual / 4 unless ($signatureSize > 0);
    $signatureSize = int($signatureSize);

    my @signatureSizes = ();
    my $np = $numPagesActual;
    while ($np > 0) {
        warn "> np=$np\n" if $debug;
        if ($np >= $signatureSize * 4) {
            push(@signatureSizes, $signatureSize);
            $np -= $signatureSize * 4;
        } else {
            push(@signatureSizes, $np / 4);
            $np = 0;
        }
    }
    warn ">> @signatureSizes\n" if $debug;

    # stack is the right order for signatures as if layout was 2x1
    my @stack = ();
    for (my $i = 0 ; $i < scalar(@signatureSizes) ; $i++) {
        my $zero = $signatureSize * $i * 4;
        my $final = $zero + $signatureSizes[$i] * 4 - 1;
        warn "sig $i [size $signatureSizes[$i]]\n" if $debug;
        for (my $j = 0 ; $j < $signatureSizes[$i] ; $j++) {
            warn "  ($j) $zero-$final\n" if $debug;
            my $card = [$final, $zero, $zero + 1, $final - 1];
            warn "      ->  @$card\n" if $debug;
            push(@stack, $card);
            $zero += 2;
            $final -= 2;
        }
    }

    # now we deal out the cards in the stack, according to layout
    my @order = ();
    my $pilesAcross = $numAcross / 2;
    my $pilesDown = $numDown;
    die "omg stack underoverflow" unless (($numSheets * $pilesAcross * $pilesDown) == scalar(@stack));
    warn "dealing: $pilesAcross x $pilesDown x $numSheets\n" if $debug;
    my @cardIndices = ();
    for (my $sh = 0 ; $sh < $numSheets ; $sh++) {
        my @shind = ();
        for (my $y = 0 ; $y < $pilesDown ; $y++) {
            for (my $x = 0 ; $x < $pilesAcross ; $x++) {
                my $cindex = $x * $numSheets + $sh + $y * $pilesAcross * $numSheets;
                warn "  $sh,$y,$x => $cindex\n" if $debug;
                push(@shind, $cindex);
                push(@cardIndices, $cindex);
            }
        }
        warn ">>> @shind\n" if $debug;
        for (my $side = 0 ; $side < 2 ; $side++) {
            for (my $y = 0 ; $y < $pilesDown ; $y++) {
                for (my $x = 0 ; $x < $pilesAcross ; $x++) {
                    my $ind = -1;
                    if ($side) {
                        $ind = $y * $pilesAcross + $pilesAcross - $x - 1;
                    } else {
                        $ind = $y * $pilesAcross + $x;
                    }
                    my @ord = ($stack[$shind[$ind]]->[$side * 2], $stack[$shind[$ind]]->[$side * 2 + 1]);
                    warn "  side=$side $y,$x ind=[$ind] (shind=$shind[$ind]) (@{$stack[$shind[$ind]]}) ==> @ord\n" if $debug;
                    push(@order, @ord);
                }
            }
        }
    }
    
    my $res = {
        numPages => $numPages,
        numPagesActual => $numPagesActual,
        numAcross => $numAcross,
        numDown => $numDown,
        numSheets => $numSheets,
        perSheet => $perSheet,
        order => \@order,
        stack => \@stack,
        cardIndices => \@cardIndices,
        signatureSize => $signatureSize,
        signatureSizes => \@signatureSizes,
        version => $VERSION,
    };
    return $res;
}



1;
