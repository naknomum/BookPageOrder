
// https://github.com/naknomum/BookPageOrder


function bookPageOrder(numPages, numAcross, numDown, signatureSize) {
    let VERSION = '0.9';
    let res = { success: false };
    let debug = true;

    if (!numPages) {
        res.error = 'must have numPages';
        return res;
    }
    numAcross = numAcross || 2;
    numDown = numDown || 1;
    if (numAcross % 2 == 1) {
        res.error = 'numAcross must be even';
        return res;
    }

    let perSheet = 2 * numAcross * numDown;
    let numSheets = Math.ceil(numPages / perSheet);
    let numPagesActual = numSheets * perSheet;
    if (!signatureSize) signatureSize = numPagesActual / 4;

    let signatureSizes = [];
    let np = numPagesActual;
    while (np > 0) {
        if (debug) console.log("> np=%d", np);
        if (np >= signatureSize * 4) {
            signatureSizes.push(signatureSize);
            np -= signatureSize * 4;
        } else {
            signatureSizes.push(np / 4);
            np = 0;
        }
    }
    if (debug) console.log(">> %o", signatureSizes);

    // stack is the right order for signatures as if layout was 2x1
    let stack = [];
    for (let i = 0 ; i < signatureSizes.length ; i++) {
        let zero = signatureSize * i * 4;
        let fin = zero + signatureSizes[i] * 4 - 1;
        if (debug) console.log("sig %d [size %o]", i, signatureSizes[i]);
        for (let j = 0 ; j < signatureSizes[i] ; j++) {
            if (debug) console.log("  (%d) %d-%d", j, zero, fin);
            let card = [fin, zero, zero + 1, fin - 1];
            if (debug) console.log("    -> %o", card);
            stack.push(card);
            zero += 2;
            fin -= 2;
        }
    }

    // now we deal out the cards in the stack, according to layout
    let order = [];
    let pilesAcross = numAcross / 2;
    let pilesDown = numDown;
    if ((numSheets * pilesAcross * pilesDown) != stack.length) {
        res.error = 'omg stack underoverflow';
        return res;
    }
    if (debug) console.log("dealing: %d x %d x %d", pilesAcross, pilesDown, numSheets);
    let cardIndices = [];
    for (let sh = 0 ; sh < numSheets ; sh++) {
        let shind = [];
        for (let y = 0 ; y < pilesDown ; y++) {
            for (let x = 0 ; x < pilesAcross ; x++) {
                let cindex = x * numSheets + sh + y * pilesAcross * numSheets;
                if (debug) console.log("  %d,%d,%d => %d", sh, y, x, cindex);
                shind.push(cindex);
                cardIndices.push(cindex);
            }
        }
        if (debug) console.log('>>> %o', shind);
        for (let side = 0 ; side < 2 ; side++) {
            for (let y = 0 ; y < pilesDown ; y++) {
                for (let x = 0 ; x < pilesAcross ; x++) {
                    let ind = -1;
                    if (side) {
                        ind = y * pilesAcross + pilesAcross - x - 1;
                    } else {
                        ind = y * pilesAcross + x;
                    }
                    let ord = [ stack[shind[ind]][side * 2], stack[shind[ind]][side * 2 + 1] ];
                    if (debug) console.log("  side=%d %d,%d ind=[%d] (shind=%o) (%o) ==> %o", side, y, x, ind, shind[ind], stack[shind[ind]], ord);
                    order.push(ord[0], ord[1]);
                }
            }
        }
    }
    
    res = {
        'numPages': numPages,
        'numPagesActual': numPagesActual,
        'numAcross': numAcross,
        'numDown': numDown,
        'numSheets': numSheets,
        'perSheet': perSheet,
        'order': order,
        'stack': stack,
        'cardIndices': cardIndices,
        'signatureSize': signatureSize,
        'signatureSizes': signatureSizes,
        'version': VERSION,
        'success': true
    };
    return res;
}

