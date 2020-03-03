
/*
 * Temporary file for use only during development when there are no library or
 * header files.
 */

//typedef unsigned long size_t;
#include "include/string.h"
/*
 *  Extremely crude standard library implementations in lieu of having a C
 *  library.
 */
unsigned long strlen( const char* pcString ){
    unsigned long len = 0;
    // assert(pcString);
    while(*pcString++ != '\0')
        len ++;
    return len;
}

int strcmp( const char *pcString1, const char *pcString2 ){
    int ret = 0;
    while( !(ret = *(const unsigned char*)pcString1 - *(const unsigned char*)pcString2) && *pcString2)
    {
        pcString1 ++;
        pcString2 ++;
    }
    if( ret < 0) ret = -1;
    else if(ret > 0) ret = 1;
    return ret;
}

void *memcpy( void *pvDest, const void *pvSource, unsigned long ulBytes ){
	char *dst = (char *) pvDest;
	const char *src = (const char *) pvSource;
	while (ulBytes--){
		*dst++ = *src++;	
	}
	return pvDest;
}

void *memset( void *pvDest, int iValue, unsigned long ulBytes ){
	unsigned char* p = (unsigned char*) pvDest;

	while(ulBytes > 0){
		*p++ = (unsigned char) iValue;
		ulBytes--;
	}
	return pvDest;
}

char * strcpy(char* _Dest, const char* _Source){
    if (NULL ==_Dest || NULL == _Source)
         return NULL;
    char* ret = _Dest;
    while((*_Dest++ = *_Source++) != '\0') ;
    return ret;
}