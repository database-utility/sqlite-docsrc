# The following data was originally generated on 2022-12-12 using
# an SQL temporary view and query against the Fossil repository
# which are embedded in regen_version_list.tcl in the docsrc repo.
#
# Either manually edit below list for each subsequent release,
# or adhere to the release tag comment convention seen below
# and rerun regen_version_list.tcl to revise the list.
#
# Data returned by below proc is used by wrap.tcl for its dateof:?
# tag substitution and pages/chronology.in for its machinations.

# Return list of lists, each a 4-tuple: uuid date vers vnum
proc chronology_info {} {
  set rv [list]
  foreach line [split {
0d1fc92f94|2023-03-22|Version 3.41.2
d0d9db8425|2023-03-10|Version 3.41.1
05941c2a04|2023-02-21|Version 3.41.0
df5c253c0b|2022-12-28|Version 3.40.1
89c459e766|2022-11-16|Version 3.40.0
a29f994989|2022-09-29|Version 3.39.4
4635f4a69c|2022-09-05|Version 3.39.3
698edb7753|2022-07-21|Version 3.39.2
7c16541a0e|2022-07-13|Version 3.39.1
14e166f40d|2022-06-25|Version 3.39.0
78d9c993d4|2022-05-06|Version 3.38.5
d402f49871|2022-05-04|Version 3.38.4
9547e2c38a|2022-04-27|Version 3.38.3
d33c709cc0|2022-03-26|Version 3.38.2
38c210fdd2|2022-03-12|Version 3.38.1
40fa792d35|2022-02-22|Version 3.38.0
872ba256cb|2022-01-06|Version 3.37.2
378629bf2e|2021-12-30|Version 3.37.1
bd41822c74|2021-11-27|Version 3.37.0
5c9a6c0687|2021-06-18|Version 3.36.0
1b256d97b5|2021-04-19|Version 3.35.5
5d4c65779d|2021-04-02|Version 3.35.4
4c5e6c200a|2021-03-26|Version 3.35.3
ea80f3002f|2021-03-17|Version 3.35.2
aea12399bf|2021-03-15|Version 3.35.1
acd63062eb|2021-03-12|Version 3.35.0
10e20c0b43|2021-01-20|Version 3.34.1
a26b6597e3|2020-12-01|Version 3.34.0
fca8dc8b57|2020-08-14|Version 3.33.0
7ebdfa80be|2020-06-18|Version 3.32.3
ec02243ea6|2020-06-04|Version 3.32.2
0c1fcf4711|2020-05-25|Version 3.32.1
5998789c9c|2020-05-22|Version 3.32.0
3bfa9cc97d|2020-01-27|Version 3.31.1
f6affdd416|2020-01-22|Version 3.31.0
18db032d05|2019-10-10|Version 3.30.1
c20a353364|2019-10-04|Version 3.30.0
fc82b73eaa|2019-07-10|Version 3.29.0
884b4b7e50|2019-04-16|Version 3.28.0
bd49a8271d|2019-02-25|Version 3.27.2
0eca3dd3d3|2019-02-08|Version 3.27.1
97744701c3|2019-02-07|Version 3.27.0
bf8c1b2b7a|2018-12-01|Version 3.26.0
89e099fbe5|2018-11-05|Version 3.25.3
fb90e7189a|2018-09-25|Version 3.25.2
2ac9003de4|2018-09-18|Version 3.25.1
b63af6c3bd|2018-09-15|Version 3.25.0
c7ee083322|2018-06-04|Version 3.24.0
4bb2294022|2018-04-10|Version 3.23.1
736b53f57f|2018-04-02|Version 3.23.0
0c55d17973|2018-01-22|Version 3.22.0
1a584e4999|2017-10-24|Version 3.21.0
8d3a7ea6c5|2017-08-24|Version 3.20.1
9501e22dfe|2017-08-01|Version 3.20.0
036ebf729e|2017-06-17|Version 3.18.2
77bb46233d|2017-06-16|Version 3.18.1
0ee482a1e0|2017-06-08|Version 3.19.3
edb4e819b0|2017-05-25|Version 3.19.2
f6d7b988f4|2017-05-24|Version 3.19.1
28a94eb282|2017-05-22|Version 3.19.0
424a0d3803|2017-03-28|Version 3.18.0
ada05cfa86|2017-02-13|Version 3.17.0
a65a62893c|2017-01-06|Version 3.16.2
979f043928|2017-01-03|Version 3.16.1
04ac0b75b1|2017-01-02|Version 3.16.0
bbd85d235f|2016-11-28|Version 3.15.2
1136863c76|2016-11-04|Version 3.15.1
707875582f|2016-10-14|Version 3.15.0
29dbef4b85|2016-09-12|Version 3.14.2
a12d805977|2016-08-11|Version 3.14.1
d5e9805702|2016-08-08|Version 3.14
fc49f556e4|2016-05-18|Version 3.13.0
92dc59fd5a|2016-04-18|Version 3.12.2
fe7d3b75fe|2016-04-08|Version 3.12.1
dfbfd34b3f|2016-03-31|Version 3.9.3
e9bb4cf40f|2016-03-29|Version 3.12.0
f047920ce1|2016-03-03|Version 3.11.1
3d862f207e|2016-02-15|Version 3.11.0
17efb4209f|2016-01-20|Version 3.10.2
254419c367|2016-01-14|Version 3.10.1
fd0a50f079|2016-01-06|Version 3.10.0
bda77dda96|2015-11-02|Version 3.9.2
767c1727fe|2015-10-16|Version 3.9.1
a721fc0d89|2015-10-14|Version 3.9.0
cf538e2783|2015-07-29|Version 3.8.11.1
b8e92227a4|2015-07-27|Version 3.8.11
2ef4f3a5b1|2015-05-20|Version 3.8.10.2
05b4b1f2a9|2015-05-09|Version 3.8.10.1
cf975957b9|2015-05-07|Version 3.8.10
8a8ffc862e|2015-04-08|Version 3.8.9
9d6c1880fb|2015-02-25|Version 3.8.8.3
7757fc7212|2015-01-30|Version 3.8.8.2
f73337e3e2|2015-01-20|Version 3.8.8.1
7d68a42fac|2015-01-16|Version 3.8.8
f66f7a17b7|2014-12-09|Version 3.8.7.4
647e77e853|2014-12-05|Version 3.8.7.3
2ab564bf96|2014-11-18|Version 3.8.7.2
3b7b72c468|2014-10-29|Version 3.8.7.1
1581c30c38|2014-10-22|Version 3.8.6.1
e4ab094f8a|2014-10-17|Version 3.8.7
9491ba7d73|2014-08-15|Version 3.8.6
b1ed4f2a34|2014-06-04|Version 3.8.5
a611fa96c4|2014-04-03|Version 3.8.4.3
02ea166372|2014-03-26|Version 3.8.4.2
018d317b12|2014-03-11|Version 3.8.4.1
530a1ee7dc|2014-03-10|Version 3.8.4
ea3317a480|2014-02-11|Version 3.8.3.1
e816dd9246|2014-02-03|Version 3.8.3
27392118af|2013-12-06|Version 3.8.2
c78be6d786|2013-10-17|Version 3.8.1
7dd4968f23|2013-09-03|Version 3.8.0.2
352362bc01|2013-08-29|Version 3.8.0.1
f64cd21e2e|2013-08-26|Version 3.8.0
118a3b3569|2013-05-20|Version 3.7.17
cbea02d938|2013-04-12|Version 3.7.16.2
527231bc67|2013-03-29|Version 3.7.16.1
66d5f2b767|2013-03-18|Version 3.7.16
c0e09560d2|2013-01-09|Version 3.7.15.2
6b85b767d0|2012-12-19|Version 3.7.15.1
cd0b37c526|2012-12-12|Version 3.7.15
091570e46d|2012-10-04|Version 3.7.14.1
c0d89d4a97|2012-09-03|Version 3.7.14
f5b5a13f73|2012-06-11|Version 3.7.13
6d326d44fd|2012-05-22|Version 3.7.12.1
d9348b2a4e|2012-05-14|Version 3.7.12
be71d2f667|2012-05-14|Version 3.7.12
8654aa9540|2012-05-14|Version 3.7.12
00bb9c9ce4|2012-03-20|Version 3.7.11
ebd01a8def|2012-01-16|Version 3.7.10
c7c6050ef0|2011-11-01|Version 3.7.9
3e0da808d2|2011-09-19|Version 3.7.8
af0d91adf4|2011-06-28|Version 3.7.7.1
4374b7e83e|2011-06-23|Version 3.7.7
ed1da510a2|2011-05-19|Version 3.7.6.3
154ddbc171|2011-04-17|Version 3.7.6.2
a35e83eac7|2011-04-13|Version 3.7.6.1
f9d43fa363|2011-04-12|Version 3.7.6
ed759d5a9e|2011-02-01|Version 3.7.5
a586a4deeb|2010-12-07|Version 3.7.4
2677848087|2010-10-08|Version 3.7.3
42537b6056|2010-08-24|Version 3.7.2
3613b0695a|2010-08-23|Version 3.7.1
042a1abb03|2010-08-04|Version 3.7.0.1
b36b105eab|2010-07-21|Version 3.7.0
b078b588d6|2010-03-26|Version 3.6.23.1
4ae453ea7b|2010-03-09|Version 3.6.23
28d0d77107|2010-01-06|Version 3.6.22
1ed88e9d01|2009-12-07|Version 3.6.21
eb7a544fe4|2009-11-04|Version 3.6.20
2a832b19b6|2009-10-30|Version 3.6.16.1
c1d499afc5|2009-10-14|Version 3.6.19
b084828a77|2009-09-11|Version 3.6.18
3665010228|2009-08-10|Version 3.6.17 (CVS 6969)
ff691a6b2a|2009-06-27|Version 3.6.16 (CVS 6829)
aff34826aa|2009-06-15|Version 3.6.15 (CVS 6760)
ab76d1a252|2009-05-25|Version 3.6.14.2 (CVS 6680)
e4267c87e5|2009-05-19|Version 3.6.14.1 (CVS 6655)
469ad1ded3|2009-05-07|Version 3.6.14 (CVS 6615)
982cc7f4e7|2009-04-13|Version 3.6.13 (CVS 6502)
0db862a23a|2009-03-31|Version 3.6.12 (CVS 6418)
6abd630c87|2009-02-18|Version 3.6.11 (CVS 6299)
21b720cc9b|2009-01-15|Version 3.6.10 (CVS 6184)
b6ce8199a9|2009-01-14|Version 3.6.9 (CVS 6175)
8ca0b7c136|2009-01-12|Version 3.6.8 (CVS 6170)
f4f40370fb|2008-12-16|Version 3.6.7 (CVS 6033)
30a2080777|2008-11-26|Version 3.6.6.2 (CVS 5960)
c2266aa094|2008-11-22|Version 3.6.6.1 (CVS 5948)
01a6e2820a|2008-11-19|Version 3.6.6 (CVS 5931)
369f74983b|2008-11-12|Version 3.6.5 (CVS 5897)
cd73cffab3|2008-10-15|Version 3.6.4 (CVS 5825)
1634fd223d|2008-09-22|Version 3.6.3 (CVS 5729)
88c51b9f15|2008-08-30|Version 3.6.2 (CVS 5647)
65ab777fd0|2008-08-06|Version 3.6.1 (CVS 5540)
1841aee604|2008-07-16|Version 3.6.0 (CVS 5423)
b6129f4cc2|2008-05-14|Version 3.5.9 (CVS 5131)
6a2e3eb26a|2008-04-16|Version 3.5.8 (CVS 5019)
9a6583d375|2008-03-17|Version 3.5.7 (CVS 4874)
1d82ab6987|2008-02-06|Version 3.5.6 (CVS 4777)
cb5bf4642f|2008-01-31|Version 3.5.5 (CVS 4764)
cf4a11b2a8|2007-12-14|Version 3.5.4 (CVS 4635)
a39007d5b1|2007-11-27|Version 3.5.3 (CVS 4566)
60da01630a|2007-11-05|Version 3.5.2 (CVS 4531)
81cf518646|2007-10-04|Version 3.5.1 (CVS 4465)
1b690be22a|2007-09-04|Version 3.5.0 Alpha (CVS 4391)
64989904d4|2007-08-13|Version 3.4.2 (CVS 4218)
81a4dd07c1|2007-07-20|Version 3.4.1 (CVS 4170)
2647980fba|2007-06-18|Version 3.4.0 (CVS 4085)
16979f4525|2007-04-25|Version 3.3.17 (CVS 3872)
8c6b5adb5c|2007-04-18|Version 3.3.16 (CVS 3853)
ba5f4a55fa|2007-04-09|Version 3.3.15 (CVS 3831)
3dbf4f98ac|2007-04-02|Version 3.3.14 (CVS 3799)
286c4eb30d|2007-02-13|Version 3.3.13 (CVS 3641)
fc66070393|2007-01-27|Version 3.3.12 (CVS 3616)
66cbbe0442|2007-01-22|Version 3.3.11 (CVS 3599)
204a212a28|2007-01-10|Version 3.3.10 (CVS 3587)
8bf19a6a41|2007-01-04|Version 3.3.9 (CVS 3557)
0658bb9e3f|2006-10-09|Version 3.3.8 (CVS 3469)
85434a4b96|2006-08-12|Version 3.3.7 (CVS 3348)
c11cb07e4b|2006-06-06|Version 3.3.6 (CVS 3206)
a091a61d88|2006-04-05|Version 3.3.5 (CVS 3167)
033aaab67f|2006-02-11|Version 3.3.4 (CVS 3083)
10a3f56546|2006-01-31|Version 3.3.3 (CVS 3046)
1fdde6c506|2006-01-24|Version 3.3.2 (beta) (CVS 3019)
bd7c569993|2006-01-16|Version 3.3.1 (alpha) (CVS 2953)
59a7a56c1b|2006-01-11|Version 3.3.0 (alpha) (CVS 2915)
50d7e50a96|2005-12-19|Version 2.8.17 (CVS 2836)
e61382aed4|2005-12-19|Version 3.2.8 (CVS 2835)
bd141a7c12|2005-09-24|Version 3.2.7 (CVS 2736)
1cdfe66714|2005-09-17|Version 3.2.6 (CVS 2716)
b2415a749c|2005-08-27|Version 3.2.5 (CVS 2634)
8cef2c1ae7|2005-08-24|Version 3.2.4 (CVS 2619)
f620319b44|2005-08-21|Version 3.2.3 (CVS 2610)
0e190e9d91|2005-06-12|Version 3.2.2 (CVS 2511)
844f01af72|2005-03-29|Version 3.2.1 (CVS 2433)
debf40e8ff|2005-03-21|Version 3.2.0 (CVS 2415)
6a3f4e4be6|2005-03-17|Version 3.1.6 (CVS 2392)
b1792ae516|2005-03-11|Version 3.1.5 (CVS 2382)
3d070a9b4d|2005-03-11|Version 3.1.4 (CVS 2378)
957333a7b2|2005-02-28|Version 3.1.3.1 (not an official release) (CVS 2364)
36dbf5e929|2005-02-20|Version 3.1.3 (CVS 2356)
e9012d917a|2005-02-15|Version 3.1.2 (CVS 2337)
2efbbba55a|2005-02-15|Version 2.8.16 (CVS 2336)
2e1c71c468|2005-02-01|Version 3.1.1 (beta) (CVS 2306)
45094abe38|2005-01-21|Version 3.1.0 (alpha) (CVS 2260)
7dd66d7653|2004-10-12|Version 3.0.8 (CVS 2021)
d82ded9543|2004-09-18|Version 3.0.7 (CVS 1970)
c190b95c30|2004-09-02|Version 3.0.6 (beta) (CVS 1934)
f3fe8c9fa6|2004-08-29|Version 3.0.5 (beta) (CVS 1916)
98edbdd517|2004-08-09|Version 3.0.4 (beta) (CVS 1884)
068b15ae2a|2004-07-22|Version 3.0.3 (CVS 1860)
102ab94167|2004-07-22|Version 2.8.15 (CVS 1859)
26a559b658|2004-06-30|Version 3.0.2 (Beta) (CVS 1791)
ac6683e380|2004-06-22|Version 3.0.1 ALPHA (CVS 1669)
8b409aaae4|2004-06-18|Version 3.0.0 (ALPHA) (CVS 1619)
7d3937743f|2004-06-09|Version 2.8.14 (CVS 1554)
4d5bbb3dc3|2004-03-08|Version 2.8.13 (CVS 1287)
1736d415d7|2004-02-08|Version 2.8.12 (CVS 1213)
a9f25347de|2004-01-14|Version 2.8.11 (CVS 1177)
8bef75ab85|2004-01-14|Version 2.8.10 (CVS 1174)
d8ae6bddeb|2004-01-06|Version 2.8.9 (CVS 1160)
a0451ccf2d|2003-12-18|Version 2.8.8 (CVS 1135)
d48b0b018d|2003-12-04|Version 2.8.7 (CVS 1124)
0bde7ae2ba|2003-08-22|Version 2.8.6 (CVS 1080)
95fba440e7|2003-07-22|Version 2.8.5 (CVS 1063)
7f5e8894ae|2003-06-29|Version 2.8.4 (CVS 1041)
433570e3e6|2003-06-04|Version 2.8.3 (CVS 1002)
f542e5fc88|2003-05-17|Version 2.8.2 (CVS 983)
590f963b65|2003-05-17|Version 2.8.1 (CVS 980)
5db98b3f40|2003-02-16|Version 2.8.0 (CVS 870)
bdba796f3b|2003-01-25|Version 2.7.6 (CVS 850)
ee95eefe12|2002-12-28|Version 2.7.5 (CVS 806)
0224db6f8c|2002-12-17|Version 2.7.4 (CVS 803)
4051dbdb05|2002-10-31|Version 2.7.3 (CVS 775)
59ba43449a|2002-09-25|Version 2.7.2 (CVS 756)
5f51e13d56|2002-08-31|Version 2.7.1 (CVS 737)
9e341d9c93|2002-08-25|Version 2.7.0 (CVS 729)
ba706aca0a|2002-08-13|Version 2.6.3 (CVS 707)
223a2150ac|2002-07-31|Version 2.6.2 (CVS 699)
610b7bc70a|2002-07-19|Version 2.6.1 (CVS 691)
cc4f824b15|2002-07-18|Version 2.6.0 Release 2 (CVS 687)
111c78e683|2002-07-07|Version 2.5.6 (CVS 664)
6284c65c17|2002-07-06|Version 2.5.5 (CVS 662)
f7159fde6b|2002-07-01|Version 2.5.4 (CVS 656)
d5cb675432|2002-06-25|Version 2.5.3 (CVS 645)
756310cad2|2002-06-25|Version 2.5.2 (CVS 641)
5e8a3131ab|2002-06-19|Version 2.5.1 (CVS 629)
9baef3e240|2002-06-17|Version 2.5.0 (CVS 627)
06cdaf1c80|2002-05-10|Version 2.4.12 (CVS 561)
b13151794b|2002-05-08|Version 2.4.11 (CVS 555)
5f3618142f|2002-05-03|Version 2.4.10 (CVS 550)
0691720a4b|2002-04-22|Version 2.4.9 (CVS 542)
d703a2c5c4|2002-04-20|Version 2.4.8 (CVS 538)
977abbaebe|2002-04-12|Version 2.4.7 (CVS 528)
5ae7efd87f|2002-04-02|Version 2.4.6 (CVS 516)
b18a7b777c|2002-04-02|Version 2.4.5 (CVS 514)
c4b6c0be00|2002-03-30|Version 2.4.4 (CVS 509)
99d6764e57|2002-03-23|Version 2.4.3 (CVS 440)
49d0323255|2002-03-20|Version 2.4.2 (CVS 441)
9f12b8805f|2002-03-13|Version 2.4.1 (CVS 442)
9333ecca1e|2002-03-13|Version 2.4.1 (CVS 430)
d3f66b44e5|2002-03-11|Version 2.4.0 (CVS 443)
72c5a92aa6|2002-02-19|Version 2.3.3 (CVS 444)
4d06700007|2002-02-14|Version 2.3.2 (CVS 446)
846148d6e3|2002-02-13|Version 2.3.1 (CVS 445)
4c7dfd9353|2002-02-03|Version 2.3.0 (CVS 447)
af3bb80810|2002-01-28|Version 2.2.5 (CVS 448)
16712dae4f|2002-01-22|Version 2.2.4 (CVS 449)
a4fe893ce7|2002-01-16|Version 2.2.3 (CVS 450)
7da00a33fe|2002-01-14|Version 2.2.2 (CVS 451)
61c38f3bfe|2002-01-09|Version 2.2.1 (CVS 452)
6bb62d8fab|2001-12-22|Version 2.2.0 (CVS 453)
0d44465347|2001-12-15|Version 2.1.7 (CVS 454)
6ecd90b6c3|2001-12-14|Version 2.1.6 (CVS 455)
8e90ad552f|2001-12-06|Version 2.1.5 (CVS 456)
121c522e67|2001-12-05|Version 2.1.4 (CVS 457)
974d42839b|2001-11-24|Version 2.1.3 (CVS 458)
f14835df32|2001-11-23|Version 2.1.2 (CVS 459)
be228cd13a|2001-11-13|Version 2.1.1 (CVS 460)
56d8390e47|2001-11-12|Version 2.1.0 (CVS 461)
0fd2874205|2001-11-04|Version 2.0.8 (CVS 462)
b0442cb9c6|2001-10-22|Version 2.0.7 (CVS 463)
c8535a0de9|2001-10-19|Version 2.0.6 (CVS 464)
e2d84f71ed|2001-10-15|Version 2.0.5 (CVS 465)
444447007a|2001-10-13|Version 2.0.4 (CVS 466)
a8fee23f86|2001-10-13|Version 2.0.3 (CVS 467)
44d00a6f58|2001-10-09|Version 2.0.2 (CVS 468)
e498084940|2001-10-02|Version 2.0.1 (CVS 469)
c0a8a1fb42|2001-09-28|Version 2.0.0 (CVS 470)
cfc86dc48a|2001-07-23|Version 1.0.32 (CVS 471)
a7bfcbb413|2001-04-15|Version 1.0.31 (CVS 472)
8f0d98193e|2001-04-06|Version 1.0.30 (CVS 473)
4b3ffa161a|2001-04-05|Version 1.0.29 (CVS 474)
8b4c87e8cf|2001-04-04|Version 1.0.28 (CVS 475)
833291c227|2001-03-20|Version 1.0.27 (CVS 476)
99f9ea412f|2001-03-20|Version 1.0.26 (CVS 477)
7564b223ab|2001-03-15|Version 1.0.25 (CVS 478)
34b17e6ce1|2001-03-14|Version 1.0.24 (CVS 479)
cbfa44c323|2001-02-20|Version 1.0.23 (CVS 480)
ec861066e3|2001-02-19|Version 1.0.22 (CVS 481)
7a1147ff52|2001-02-19|Version 1.0.21 (CVS 482)
eb0a523c49|2001-02-11|Version 1.0.20 (CVS 484)
08e179b076|2001-02-06|Version 1.0.19 (CVS 483)
46b86abb1c|2001-01-04|Version 1.0.18 (CVS 485)
bee0c81859|2000-12-10|Version 1.0.17 (CVS 486)
8c36b248fd|2000-11-28|Version 1.0.16 (CVS 487)
d2ad3d2b4e|2000-10-23|Version 1.0.15 (CVS 488)
4788dc32a5|2000-10-19|Version 1.0.14 (CVS 489)
b9c84fa579|2000-10-19|Version 1.0.13 (CVS 490)
7330218a91|2000-10-17|Version 1.0.12 (CVS 491)
e0c9e80bdb|2000-10-11|Version 1.0.10 (CVS 492)
ebbb9e4a66|2000-10-09|Version 1.0.9 (CVS 493)
384909e50f|2000-09-30|Version 1.0.8 (CVS 494)
84839d8764|2000-09-14|Version 1.0.5 (CVS 495)
92346e003e|2000-08-28|Version 1.0.4 (CVS 496)
d35a1f8b37|2000-08-22|Version 1.0.3 (CVS 497)
e8521fc10d|2000-08-18|Version 1.0.1 (CVS 498)
f37dd18e3f|2000-08-17|Version 1.0 (CVS 499)
} \n] {
    if {[string trim $line]==""} continue
    foreach {uuid date vers1} [split $line |] break
    regexp {[123]\.[0-9.]+} $vers1 vers
    set vers [string trim $vers .]
    set vlist [split $vers .]
    set vnum [expr {1000000*[lindex $vlist 0]+10000*[lindex $vlist 1]}]
    if {[lindex $vlist 2]!=""} {
      incr vnum [expr {100*[lindex $vlist 2]}]
      if {[lindex $vlist 3]!=""} {
        incr vnum [lindex $vlist 3]
      }
    }
    lappend rv [list $uuid $date $vers $vnum]
  }
  return $rv
}
