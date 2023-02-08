# BookPageOrder

Algorithm and utility for ordering pages for N-up layout, including support for signature. Useful for bookbinding, zines, etc.

The required input is **number of pages**, with optional parameters of **pages across**, **pages down** (for _N-up printing_, defaults to 2 and 1 respectively),
and **signature size** (number of sheets per signature).

_Pages across_ must be even, as this expects to be used for binding full folios. It is considered beyond the intention of this project to handle single-width
output. The total number of pages actually output will be rounded up (if necessary) to the next "boundary" for the parameters passed in. This is always going to be
a multiple of 4, but can be even larger for complex parameters used.

* `BookPageOrder.pm` is a perl module implementation

* `BookPageOrder.js` is a javascript implementation

## Example output

The algorithm generates a data strcuture with various calculated values. Most likely the desired element is `order`, which is the ordering the pages should
be printed for the desired parameters.  This output is for parameters `numPages=15`, `numAcross=2`, and `numDown=1`.
(Output is shown as JSON for convenience, but is actually a hash/object.)

```json
{
   "numPages" : 15,
   "numAcross" : 2,
   "numDown" : 1,
   "numPagesActual" : 16,

   "order" : [ 15, 0, 1, 14, 13, 2, 3, 12, 11, 4, 5, 10, 9, 6, 7, 8 ],

   "numSheets" : 4,
   "perSheet" : 4,
   "signatureSize" : 4,
   "signatureSizes" : [ 4 ],
   "stack" : [
      [ 15, 0, 1, 14 ],
      [ 13, 2, 3, 12 ],
      [ 11, 4, 5, 10 ],
      [ 9, 6, 7, 8 ]
   ],
   "cardIndices" : [ 0, 1, 2, 3 ]
}
```

## book_order_util

A small utility for applying the BookPageOrder algorithm.  Generic arguments are: `book_order_util.pl numPages [numAcross [numDown [signatureSize]]]`.
Operation examples are listed below.

* `book_order_util.pl` with _no flag_ will simply output the order array (one number per line): `book_order_util.pl 16 > ordering.dat`

* `book_order_util.pl -d` will output the whole data structure (as above) as json: `book_order_util.pl -d 15 2 1 > ordering.json`

* `book_order_util.pl -t` will output a test pdf which illustrates layout: `book_order_util.pl -d 16 4 4 > test.pdf`

![example test pdf](test-example.png)


## Technical information on ordering, assembly, etc.

More [details on page ordering conventions](details.md) is available, along with other details.
