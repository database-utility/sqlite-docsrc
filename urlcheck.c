/*
** 2022 December 31
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This file implements a URL checker. See zUsage below for operation.
** It should compile on Linux systems having a certain Curl library.
**   apt install libcurl4-openssl-dev
** Build executable thusly:
**   gcc urlcheck.c -Os -o urlcheck -lcurl
*/

const char *zUsage = "\
Usage: urlcheck [<options>] [<urls>]|[--help]\n\
If URL arguments are provided, they are checked for HTTP server responses.\n\
If no URLs are provided, URLs are read 1 per line from stdin and checked.\n\
Output is bar-separated 3-tuple lines of URL, response_code, code_as_text.\n\
Option --ok-silent suppresses output for URLs yielding an HTTP 200 response.\n\
";
#include <stdio.h>
#include <stdlib.h>
#ifdef __STDC_ALLOC_LIB__
#define __STDC_WANT_LIB_EXT2__ 1
#else
#define _POSIX_C_SOURCE 200809L
#endif
#include <string.h>
#include <curl/curl.h>

typedef struct XfrStatus {
  int iStatus;
  size_t nAlloc;
  char *zText;
} XfrStatus;

static size_t header_sift(char *buf, size_t sz, size_t ni, void *pv){
  XfrStatus *pxs = (XfrStatus *)pv;
  if( ni>6 && strncmp(buf, "HTTP", 4) == 0 ){
    int respcode = 0, i;
    int nr = 0;
    char c = buf[ni-1], cjunk;
    buf[ni-1] = 0;
    for( i=4; i<ni; ++i){
      if( buf[i] == ' ' ) break;
    }
    if( 2 == sscanf(buf+i, "%d%c%n", &respcode, &cjunk, &nr) ){
      pxs->iStatus = respcode;
      if( pxs->zText != 0 ) free(pxs->zText);
      pxs->zText = strdup( &buf[i+nr] );
    }
    buf[ni-1] = c;
  }
  return sz * ni;
}

static size_t body_toss(char *buf, size_t sz, size_t ni, void *pv){
  (void)buf;
  (void)pv;
  return sz * ni;
}

/* Say whether response code is one given by servers rejecting HEAD requests. */
int is_picky_no_response( int rcode ){
  static int aprc[] = { 403, 405, 502, 503 };
  int ix = 0;
  while( ix < sizeof(aprc)/sizeof(int) ){
    if( rcode == aprc[ix] ) return 1;
    ++ix;
  }
  return 0;
}

#define SAY_USER_AGENT "libcurl-agent/1.0"

void one_url( CURL *pCurl, char *zUrl, XfrStatus *pxs, int okhush, int depth){
  CURLcode crc;
  curl_easy_setopt(pCurl, CURLOPT_URL, zUrl);
  pxs->iStatus = 0;
  if( CURLE_OK != (crc = curl_easy_perform(pCurl)) ){
    fprintf(stdout, "%s|%d|%s\n", zUrl, -1, curl_easy_strerror(crc));
  }else{
    char *zRS = pxs->zText;
    if( zRS == 0 ) zRS = "?";
    else if( *zRS < ' ' ){
      switch( pxs->iStatus ){
      case 200: zRS = "OK"; break;
      case 404: zRS = "Not Found"; break;
      case 405: zRS = "Not Allowed"; break;
      case 503: zRS = "Service Unavailable"; break;
      default: zRS = "?";
      }
    }
    /* If request of header only is rejected, do the whole GET anyway. */
    if( pxs->iStatus!=200 && is_picky_no_response(pxs->iStatus) && depth==0 ){
      if( pxs->iStatus == 503 ){
        curl_easy_setopt(pCurl, CURLOPT_USERAGENT, "Mozilla 5.0");
      }
      curl_easy_setopt(pCurl, CURLOPT_NOBODY, 0);
      one_url(pCurl, zUrl, pxs, okhush, depth+1);
      curl_easy_setopt(pCurl, CURLOPT_USERAGENT, SAY_USER_AGENT);
      curl_easy_setopt(pCurl, CURLOPT_NOBODY, 1);
    }else if( !okhush || pxs->iStatus != 200 ){
      fprintf(stdout, "%s|%d|%s\n", zUrl, pxs->iStatus, zRS);
    }
  }
  if( pxs->zText != 0 ){
    free(pxs->zText);
    pxs->zText = 0;
  }
}

int main(int na, char **av){
  int ok_silent = 0;
  XfrStatus xs = { 0, 0, 0 };
  int aix;
  CURL *pCurl = curl_easy_init();

  if( na>=2 && 0==strcmp(av[1], "--ok-silent") ){
    ok_silent = 1;
    --na; ++av;
  }

  curl_easy_setopt(pCurl, CURLOPT_USERAGENT, SAY_USER_AGENT);
  curl_easy_setopt(pCurl, CURLOPT_FOLLOWLOCATION, 1);
  curl_easy_setopt(pCurl, CURLOPT_NOPROGRESS, 1);
  curl_easy_setopt(pCurl, CURLOPT_TIMEOUT_MS, 5000L);
  curl_easy_setopt(pCurl, CURLOPT_SSL_VERIFYHOST, 0);
  curl_easy_setopt(pCurl, CURLOPT_SSL_VERIFYPEER, 0);
  curl_easy_setopt(pCurl, CURLOPT_NOBODY, 1);
  curl_easy_setopt(pCurl, CURLOPT_HEADERDATA, &xs);
  curl_easy_setopt(pCurl, CURLOPT_HEADERFUNCTION, header_sift);
  curl_easy_setopt(pCurl, CURLOPT_WRITEDATA, 0);
  curl_easy_setopt(pCurl, CURLOPT_WRITEFUNCTION, body_toss);
  if( na < 2 ){
    char lbuf[1000];
    while( 0 != fgets(lbuf, sizeof(lbuf), stdin) ){
      int nbi, nbe;
      for( nbi=0; nbi<sizeof(lbuf) && lbuf[nbi]; ++nbi )
        if( lbuf[nbi]!=' ' ) break;
      for( nbe=nbi; nbe<sizeof(lbuf) && lbuf[nbe]; ++nbe )
        if( lbuf[nbe]==' ' || lbuf[nbe] == '\n' ) break;
      if( nbi==sizeof(lbuf) || nbe==nbi ) continue;
      lbuf[nbe--] = 0;
      if( nbe==nbi ) continue;
      one_url( pCurl, &lbuf[nbi], &xs, ok_silent, 0 );
    }
  }else{
    if( na==2 && strcmp(av[1],"--help")==0 ){
      fprintf(stdout, "%s", zUsage);
    }else{
      for( aix=1; aix < na; ++aix ){
        one_url( pCurl, av[aix], &xs, ok_silent, 0 );
      }
    }
  }
  curl_easy_cleanup(pCurl);
  return 0;
}
