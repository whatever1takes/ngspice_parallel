/*
Test program for shared ngspice parallel incl. synchronization
Copyright Holger Vogt 2013

Currently set up and tested only for MS Visual Studio 2008

ngspice libraries are loaded dynamically.

Test 1
Load and initialize two ngspice shared libs
Source an input file adder_mos.cir for both libs
Run the simulation, each in its own background thread
Stop the simulation for 5 seconds in thraed 1
Resume the simulation in the background thread
Write rawfiles test1.raw and test2.raw
Unload ngspice libs

Test 2
Load and initialize three ngspice instances.
Run a simulation with three inverter chains in series,
emulating a circuit partitioned into three parts.
Each partition runs in its own ngspice instance. They are
synchronized via a commonly used callback function.
Each inverter is blanked out by a NAND gate during 
a small time period, just to show that there is no interference.
Circuit coupling is only by the two interfaces Vout1 --> Vin2, 
Vout2 --> Vin3.

This example is by far not ready: sometimes synchronization is lost, 
spuriously a thread may jump ahead and finish (too) early. More
experience in multithreaded programming is required from my side.
*/



#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <assert.h>

#ifndef _MSC_VER
#include <stdbool.h>
#include <pthread.h>
#include <stdint.h>
#else
#define bool int
#define true 1
#define false 0
#define strdup _strdup
typedef signed __int64       int64_t;
#endif
#include "../include/sharedspice.h"


#if defined(__MINGW32__) ||  defined(_MSC_VER)
#undef BOOLEAN
#include <windows.h>
typedef FARPROC funptr_t;
void *dlopen (const char *, int);
funptr_t dlsym (void *, const char *);
int dlclose (void *);
char *dlerror (void);
#define RTLD_LAZY	1	/* lazy function call binding */
#define RTLD_NOW	2	/* immediate function call binding */
#define RTLD_GLOBAL	4	/* symbols in this dlopen'ed obj are visible to other dlopen'ed objs */
static char errstr[128];
#else
#include <dlfcn.h> /* to load libraries*/
#include <unistd.h>
#include <ctype.h>
typedef void *  funptr_t;
#endif

/* Defines for thread handling, as a unified interface for pthreads
   and MS Windows threads*/
/* MS Windows */
#if defined(__MINGW32__) || defined(_MSC_VER)
#define mutex_lock(a) EnterCriticalSection(a)
#define mutex_unlock(a) LeaveCriticalSection(a)
#define mutex_init(a) InitializeCriticalSection(a)
#define mutex_delete(a) DeleteCriticalSection(a)
typedef CRITICAL_SECTION mutexType;
#define thread_self() GetCurrentThread()
#define threadid_self() GetThreadId(GetCurrentThread())
typedef HANDLE threadId_t;
/* LINUX, CYGWIN, etc. */
#else
#include <pthread.h>
#define mutex_lock(a) pthread_mutex_lock(a)
#define mutex_unlock(a) pthread_mutex_unlock(a)
#define mutex_init(a) pthread_mutex_init(a, NULL)
#define mutex_delete(a) pthread_mutex_destroy(a)
#define thread_self() pthread_self()
typedef pthread_mutex_t mutexType;
typedef pthread_t threadId_t;
#endif

bool no_bg = true;
bool not_yet = true;
bool will_unload = false;
int numthreads = 0;

/* case insensitive string comparison */
int cieq(register char *p, register char *s);
/* comparing two double numbers */
bool AlmostEqualUlps(double A, double B, int maxUlps);

/* callback functions used by ngspice, initialized by ngSpice_Init() */
int
ng_getchar(char* outputreturn, int ident, void* userdata);

int
ng_getstat(char* outputreturn, int ident, void* userdata);

int
ng_thread_runs(bool noruns, int ident, void* userdata);

ControlledExit ng_exit;
SendData ng_data;
SendInitData ng_initdata;

/* callback functions used by ngspice, initialized by ngSpice_Init_Sync() */

GetVSRCData ng_VSRCData;
GetISRCData ng_ISRCData;
GetSyncData ng_SyncData;

int vecgetnumber1 = 0, vecgetnumber2 = 0;
double v2dat;
static bool has_break = false;
int testnumber = 0;

/* functions exported by ngspice1 */
funptr_t ngSpice_Init_handle1 = NULL;
funptr_t ngSpice_Init_Sync_handle1 = NULL;
funptr_t ngSpice_Command_handle1 = NULL;
funptr_t ngSpice_Circ_handle1 = NULL;
funptr_t ngSpice_CurPlot_handle1 = NULL;
funptr_t ngSpice_AllVecs_handle1 = NULL;
funptr_t ngSpice_GVI_handle1 = NULL;

/* functions exported by ngspice2 */
funptr_t ngSpice_Init_handle2 = NULL;
funptr_t ngSpice_Init_Sync_handle2 = NULL;
funptr_t ngSpice_Command_handle2 = NULL;
funptr_t ngSpice_Circ_handle2 = NULL;
funptr_t ngSpice_CurPlot_handle2 = NULL;
funptr_t ngSpice_AllVecs_handle2 = NULL;
funptr_t ngSpice_GVI_handle2 = NULL;

/* functions exported by ngspice3 */
funptr_t ngSpice_Init_handle3 = NULL;
funptr_t ngSpice_Init_Sync_handle3 = NULL;
funptr_t ngSpice_Command_handle3 = NULL;
funptr_t ngSpice_Circ_handle3 = NULL;
funptr_t ngSpice_CurPlot_handle3 = NULL;
funptr_t ngSpice_AllVecs_handle3 = NULL;
funptr_t ngSpice_GVI_handle3 = NULL;

void * ngdllhandle1 = NULL;
void * ngdllhandle2 = NULL;
void * ngdllhandle3 = NULL;

/* simple thread identification numbers */
int dll1 = 1, dll2 = 2, dll3 = 3;

int numtreads = 0, threadmax = 0;
bool ok1 = false, ok2 = false;

mutexType rt_cs; // used in ng_thread_runs()
mutexType sy_cs1; // used in ng_SyncData()
mutexType sy_cs2; // used in ng_SyncData()
mutexType sy_cs3; // used in ng_SyncData()

#define int64_min (((int64_t) -1) << 63)
#ifdef _MSC_VER
#define llabs(x) ((x) < 0 ? -(x) : (x))
#endif

bool AlmostEqualUlps(double A, double B, int maxUlps)
{
    int64_t aInt, bInt, intDiff;

    union {
        double d;
        int64_t i;
    } uA, uB;

    if (A == B)
        return true;

    /* If not - the entire method can not work */
    assert(sizeof(double) == sizeof(int64_t));

    /* Make sure maxUlps is non-negative and small enough that the */
    /* default NAN won't compare as equal to anything. */
    assert(maxUlps > 0 && maxUlps < 4 * 1024 * 1024);

    uA.d = A;
    aInt = uA.i;
    /* Make aInt lexicographically ordered as a twos-complement int */
    if (aInt < 0)
        aInt = int64_min - aInt;

    uB.d = B;
    bInt = uB.i;
    /* Make bInt lexicographically ordered as a twos-complement int */
    if (bInt < 0)
        bInt = int64_min - bInt;

    intDiff = llabs(aInt - bInt);

    /* printf("A:%e B:%e aInt:%d bInt:%d  diff:%d\n", A, B, aInt, bInt, intDiff); */

    if (intDiff <= maxUlps)
        return true;
    return false;
}


/* Case insensitive str eq. */
/* Like strcasecmp( ) XXX */

int
cieq(register char *p, register char *s)
{
    while (*p) {
        if ((isupper(*p) ? tolower(*p) : *p) !=
                (isupper(*s) ? tolower(*s) : *s))
            return(false);
        p++;
        s++;
    }
    return (*s ? false : true);
}


/* Unify LINUX and Windows dynamic library handling */
#if defined(__MINGW32__) ||  defined(_MSC_VER)

void *dlopen(const char *name,int type)
{
    return LoadLibrary((LPCSTR)name);
}

funptr_t dlsym(void *hDll, const char *funcname)
{
    return GetProcAddress(hDll, funcname);
}

char *dlerror(void)
{
    LPVOID lpMsgBuf;
    char * testerr;
    DWORD dw = GetLastError();

    FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        dw,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR) &lpMsgBuf,
        0,
        NULL
    );
    testerr = (char*)lpMsgBuf;
    strcpy(errstr,lpMsgBuf);
    LocalFree(lpMsgBuf);
    return errstr;
}

int dlclose (void *lhandle)
{
    return (int)FreeLibrary(lhandle);
}
#endif

/**************************************************************************************/
/**************************************************************************************/


double in1out2 = 0.0, in2out1 = 0.0, in3out2 = 0.0;

int main()
{
    char *errmsg = NULL, *loadstring1, *loadstring2, *loadstring3, *curplot, *vecname;
    char *exepath, *exeptr;
    int *ret, i;
    char ** circarray;
    char **vecarray;
    char newpath[256];

/* mutex initializing */
    mutex_init(&rt_cs);
    mutex_init(&sy_cs1);
    mutex_init(&sy_cs2);
    mutex_init(&sy_cs3);

#if defined(__MINGW32__) || defined(_MSC_VER)
    /* find path of executable */
    _get_pgmptr(&exepath); 
    exeptr = strrchr(exepath, '\\');
    *(++exeptr) = '\0';
    sprintf(newpath, "%sngspice.dll", exepath);
#endif

    goto next;  /* skip example 1 */

    printf("***********************************\n");
    printf("**  ngspice parrallel example 1  **\n");
    printf("***********************************\n");


    printf("Load ngspice.dll\n");
#ifdef __CYGWIN__
    loadstring1 = "/cygdrive/c/cygwin/usr/local/bin/cygngspice-0.dll";
#elif _MSC_VER
    loadstring1 = "ngspice.dll";
#else
    loadstring1 = "libngspice1.so";
#endif
    dlerror();

    ngdllhandle1 = dlopen(loadstring1, RTLD_NOW);

    errmsg = dlerror();
    if (errmsg)
        printf("%s\n", errmsg);
    if (ngdllhandle1) {
        printf("%s loaded\n", loadstring1);
        numthreads++;
    } else {
        printf("%s not loaded !\n", loadstring1);
        exit(1);
    }

    printf("Load ngspice2.dll\n");
#ifdef __CYGWIN__
    loadstring2 = "/cygdrive/c/cygwin/usr/local/bin/cygngspice-2.dll";
#elif _MSC_VER
    loadstring2 = "ngspice2.dll";
#else
    loadstring2 = "libngspice2.so";
#endif
    ngdllhandle2 = dlopen(loadstring2, RTLD_NOW);

    errmsg = dlerror();
    if (errmsg)
        printf("%s\n", errmsg);
    if (ngdllhandle2) {
        printf("ngspice2.dll loaded\n");
        numthreads++;
    } else {
        printf("ngspice2.dll not loaded !\n");
        exit(1);
    }
    /* retrieve handles for all exported functions */
    ngSpice_Init_handle1 = dlsym(ngdllhandle1, "ngSpice_Init");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Init_Sync_handle1 = dlsym(ngdllhandle1, "ngSpice_Init_Sync");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Command_handle1 = dlsym(ngdllhandle1, "ngSpice_Command");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_CurPlot_handle1 = dlsym(ngdllhandle1, "ngSpice_CurPlot");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_AllVecs_handle1 = dlsym(ngdllhandle1, "ngSpice_AllVecs");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_GVI_handle1 = dlsym(ngdllhandle1, "ngGet_Vec_Info");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);

    ngSpice_Init_handle2 = dlsym(ngdllhandle2, "ngSpice_Init");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Init_Sync_handle2 = dlsym(ngdllhandle2, "ngSpice_Init_Sync");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Command_handle2 = dlsym(ngdllhandle2, "ngSpice_Command");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_CurPlot_handle2 = dlsym(ngdllhandle2, "ngSpice_CurPlot");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_AllVecs_handle2 = dlsym(ngdllhandle2, "ngSpice_AllVecs");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_GVI_handle2 = dlsym(ngdllhandle2, "ngGet_Vec_Info");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);

    /* initialize both shared libraries */
    ret = ((int * (*)(SendChar*, SendStat*, ControlledExit*, SendData*, SendInitData*,
                      BGThreadRunning*, void*)) ngSpice_Init_handle1)(ng_getchar, ng_getstat,
                              ng_exit, NULL, ng_initdata, ng_thread_runs, NULL);

    ret = ((int * (*)(SendChar*, SendStat*, ControlledExit*, SendData*, SendInitData*,
                      BGThreadRunning*, void*)) ngSpice_Init_handle2)(ng_getchar, ng_getstat,
                              ng_exit, NULL, ng_initdata, ng_thread_runs, NULL);

    /* just send the ngspice library identifiers */
    ret = ((int * (*)(GetVSRCData*, GetISRCData*, GetSyncData*, int*,
                      void*)) ngSpice_Init_Sync_handle1)(NULL, NULL, NULL, &dll1, NULL);

    ret = ((int * (*)(GetVSRCData*, GetISRCData*, GetSyncData*, int*,
                      void*)) ngSpice_Init_Sync_handle2)(NULL, NULL, NULL, &dll2, NULL);

    testnumber = 1;
    printf("\n**  Test no. %d: Sourcing two input files and running them independently **\n\n", testnumber);
#if defined(__CYGWIN__)
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("source /cygdrive/d/Spice_general/ngspice_sh/examples/shared-ngspice/adder_mos.cir");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("source /cygdrive/d/Spice_general/ngspice_sh/examples/shared-ngspice/adder_mos.cir");
#elif __MINGW32__
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("source D:\\Spice_general\\ngspice_sh\\examples\\shared-ngspice\\adder_mos.cir");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("source D:\\Spice_general\\ngspice_sh\\examples\\shared-ngspice\\adder_mos.cir");
#else
//    ret = ((int * (*)(char*)) ngSpice_Command_handle)("../../examples/adder_mos.cir");
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("source ./examples/adder_mos.cir");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("source ./examples/adder_mos.cir");
#endif
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("bg_run");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("bg_run");
#if defined(__MINGW32__) || defined(_MSC_VER)
    Sleep (5000);
#else
    usleep (5000000);
#endif
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("bg_halt");
    for (i = 5; i > 0; i--) {
        printf("Pause for %d seconds\n", i);
#if defined(__MINGW32__) || defined(_MSC_VER)
        Sleep (1000);
#else
        usleep (1000000);
#endif
    }
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("bg_resume");

    /* wait for 1s while simulation continues */
#if defined(__MINGW32__) || defined(_MSC_VER)
    Sleep (1000);
#else
    usleep (1000000);
#endif
    /* read current plot while simulation continues */
    curplot = ((char * (*)()) ngSpice_CurPlot_handle1)();
    printf("\nlib 1: Current plot is %s\n\n", curplot);

    /* get some data from ngspice1 */
    vecarray = ((char ** (*)(char*)) ngSpice_AllVecs_handle1)(curplot);
    /* get length of first vector */
    if (vecarray) {
        char plotvec[256];
        pvector_info myvec;
        int veclength;
        vecname = vecarray[0];
        sprintf(plotvec, "%s.%s", curplot, vecname);
        myvec = ((pvector_info (*)(char*)) ngSpice_GVI_handle1)(plotvec);
        veclength = myvec->v_length;
        printf("\nlib 1: Actual length of vector %s is %d\n\n", plotvec, veclength);
    }

    /* wait until simulation finishes */
    for (;;) {
#if defined(__MINGW32__) || defined(_MSC_VER)
        Sleep (100);
#else
        usleep (100000);
#endif
        if (no_bg)
            break;
    }
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("write test1.raw V(5)");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("write test2.raw V(5)");

    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("rusage trantime");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("rusage trantime");

    dlclose(ngdllhandle1);
    dlclose(ngdllhandle2);

//******************************************************************************************
next:

    /* load ngspice again */
    printf("***********************************\n");
    printf("**  ngspice parrallel example 2  **\n");
    printf("***********************************\n");

    printf("Copy ngspice dlls\n");

/* search for ngspice libraries 1 - 3, create them by copying, if not already existing */
#ifdef __CYGWIN__
    /*copying t.b.d.*/
    loadstring1 = "/cygdrive/c/cygwin/usr/local/bin/cygngspice-1.dll";
#elif  defined(__MINGW32__) || defined(_MSC_VER)
    SetCurrentDirectory(exepath);
    if (GetFileAttributes("ngspice.dll") == INVALID_FILE_ATTRIBUTES)
        fprintf(stderr, "File ngspice.dll not found");
    else {
        CopyFile("ngspice.dll", "ngspice1.dll", false);
        CopyFile("ngspice.dll", "ngspice2.dll", false);
        CopyFile("ngspice.dll", "ngspice3.dll", false);
    }

    printf("Load ngspice1.dll\n");
    loadstring1 = "ngspice1.dll";
#else
    /*copying t.b.d.*/
    loadstring1 = "libngspice1.so";
#endif

    dlerror();

    ngdllhandle1 = dlopen(loadstring1, RTLD_NOW);

    errmsg = dlerror();
    if (errmsg)
        printf("%s\n", errmsg);
    if (ngdllhandle1) {
        printf("%s loaded\n", loadstring1);
        numthreads++;
    } else {
        fprintf(stderr, "%s not loaded !\n", loadstring1);
        exit(1);
    }

    printf("Load ngspice2.dll\n");
#ifdef __CYGWIN__
    loadstring2 = "/cygdrive/c/cygwin/usr/local/bin/cygngspice-2.dll";
#elif  defined(__MINGW32__) || defined(_MSC_VER)
    loadstring2 = "ngspice2.dll";
#else
    loadstring2 = "libngspice2.so";
#endif

    ngdllhandle2 = dlopen(loadstring2, RTLD_NOW);

    errmsg = dlerror();
    if (errmsg)
        printf("%s\n", errmsg);
    if (ngdllhandle2) {
        printf("%s loaded\n", loadstring2);
        numthreads++;
    } else {
        fprintf(stderr, "%s not loaded !\n", loadstring2);
        exit(1);
    }

    printf("Load ngspice3.dll\n");
#ifdef __CYGWIN__
    loadstring3 = "/cygdrive/c/cygwin/usr/local/bin/cygngspice-3.dll";
#elif  defined(__MINGW32__) || defined(_MSC_VER)
    loadstring3 = "ngspice3.dll";
#else
    loadstring3 = "libngspice3.so";
#endif

    ngdllhandle3 = dlopen(loadstring3, RTLD_NOW);

    errmsg = dlerror();
    if (errmsg)
        printf("%s\n", errmsg);
    if (ngdllhandle3) {
        printf("%s loaded\n", loadstring3);
        numthreads++;
    } else {
        fprintf(stderr, "%s not loaded !\n", loadstring3);
        exit(1);
    }

    threadmax = numthreads;

    /* retrieve handles for all exported functions */
    ngSpice_Init_handle1 = dlsym(ngdllhandle1, "ngSpice_Init");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Init_Sync_handle1 = dlsym(ngdllhandle1, "ngSpice_Init_Sync");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Command_handle1 = dlsym(ngdllhandle1, "ngSpice_Command");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_CurPlot_handle1 = dlsym(ngdllhandle1, "ngSpice_CurPlot");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_AllVecs_handle1 = dlsym(ngdllhandle1, "ngSpice_AllVecs");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_GVI_handle1 = dlsym(ngdllhandle1, "ngGet_Vec_Info");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);

    ngSpice_Init_handle2 = dlsym(ngdllhandle2, "ngSpice_Init");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Init_Sync_handle2 = dlsym(ngdllhandle2, "ngSpice_Init_Sync");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Command_handle2 = dlsym(ngdllhandle2, "ngSpice_Command");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_CurPlot_handle2 = dlsym(ngdllhandle2, "ngSpice_CurPlot");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_AllVecs_handle2 = dlsym(ngdllhandle2, "ngSpice_AllVecs");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_GVI_handle2 = dlsym(ngdllhandle2, "ngGet_Vec_Info");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);

    ngSpice_Init_handle3 = dlsym(ngdllhandle3, "ngSpice_Init");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Init_Sync_handle3 = dlsym(ngdllhandle3, "ngSpice_Init_Sync");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_Command_handle3 = dlsym(ngdllhandle3, "ngSpice_Command");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_CurPlot_handle3 = dlsym(ngdllhandle3, "ngSpice_CurPlot");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_AllVecs_handle3 = dlsym(ngdllhandle3, "ngSpice_AllVecs");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);
    ngSpice_GVI_handle3 = dlsym(ngdllhandle3, "ngGet_Vec_Info");
    errmsg = dlerror();
    if (errmsg)
        printf(errmsg);

    /* initialize all shared libraries */
    ret = ((int * (*)(SendChar*, SendStat*, ControlledExit*, SendData*, SendInitData*,
                      BGThreadRunning*, void*)) ngSpice_Init_handle1)(ng_getchar, ng_getstat,
                              ng_exit, ng_data, ng_initdata, ng_thread_runs, NULL);

    ret = ((int * (*)(SendChar*, SendStat*, ControlledExit*, SendData*, SendInitData*,
                      BGThreadRunning*, void*)) ngSpice_Init_handle2)(ng_getchar, ng_getstat,
                              ng_exit, ng_data, ng_initdata, ng_thread_runs, NULL);

    ret = ((int * (*)(SendChar*, SendStat*, ControlledExit*, SendData*, SendInitData*,
                      BGThreadRunning*, void*)) ngSpice_Init_handle3)(ng_getchar, ng_getstat,
                              ng_exit, ng_data, ng_initdata, ng_thread_runs, NULL);

    /* initialze the sync callbacks and the library identifiers */
    ret = ((int * (*)(GetVSRCData*, GetISRCData*, GetSyncData*, int*,
                      void*)) ngSpice_Init_Sync_handle1)(ng_VSRCData, ng_ISRCData, ng_SyncData, &dll1, NULL);

    ret = ((int * (*)(GetVSRCData*, GetISRCData*, GetSyncData*, int*,
                      void*)) ngSpice_Init_Sync_handle2)(ng_VSRCData, ng_ISRCData, ng_SyncData, &dll2, NULL);

    ret = ((int * (*)(GetVSRCData*, GetISRCData*, GetSyncData*, int*,
                      void*)) ngSpice_Init_Sync_handle3)(ng_VSRCData, ng_ISRCData, ng_SyncData, &dll3, NULL);


    testnumber = 2;
    printf("\n**  Test no. %d: Load three netlists, run synchronized **\n\n", testnumber);

    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("source ./examples/inv_oc1.cir");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("source ./examples/inv_oc2.cir");
    ret = ((int * (*)(char*)) ngSpice_Command_handle3)("source ./examples/inv_oc3.cir");


    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("bg_run");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("bg_run");
    ret = ((int * (*)(char*)) ngSpice_Command_handle3)("bg_run");

    i = 0;
    /* wait until simulation finishes */
    for (;;) {
#if defined(__MINGW32__) || defined(_MSC_VER)
        Sleep (100);
#else
        usleep (100000);
#endif
        if (no_bg)
            break;
        /* handle out-of-sync */
        if ((numthreads < 3) && (numthreads > 1)) {
            if (i == 0)
                fprintf(stderr, "\nWarning: if not during final step,\n   check for out-of-sync!\n\n");
            ok1 = ok2 = true;
            i++;
            if (i > 100) {
                fprintf(stderr, "\nWarning: premature end due to out-of-sync!\n\n");
                break;
            }
        }
    }

    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("write nsynctest1.raw all");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("write nsynctest2.raw all");
    ret = ((int * (*)(char*)) ngSpice_Command_handle3)("write nsynctest3.raw all");
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("rusage");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("rusage");
    ret = ((int * (*)(char*)) ngSpice_Command_handle3)("rusage");
    ret = ((int * (*)(char*)) ngSpice_Command_handle1)("rusage trantime");
    ret = ((int * (*)(char*)) ngSpice_Command_handle2)("rusage trantime");
    ret = ((int * (*)(char*)) ngSpice_Command_handle3)("rusage trantime");

    dlclose(ngdllhandle1);
    dlclose(ngdllhandle2);
    dlclose(ngdllhandle3);
    mutex_delete(&rt_cs);
    mutex_delete(&sy_cs1);
    mutex_delete(&sy_cs2);
    mutex_delete(&sy_cs3);
    printf("\n****** End of simulation ******\n");
    return 0;
}


/* Callback function called from bg thread in ngspice to transfer
   any string created by printf or puts. Output to stdout in ngspice is
   preceded by token stdout, same with stderr.*/
int
ng_getchar(char* outputreturn, int ident, void* userdata)
{
    printf("lib %d: %s\n", ident, outputreturn);
    return 0;
}

/* Callback function called from bg thread in ngspice to transfer
   simulation status (type and progress in percent. */
int
ng_getstat(char* outputreturn, int ident, void* userdata)
{
    printf("lib %d: %s\n", ident, outputreturn);
    return 0;
}


/* Callback function called from bg thread in ngspice if fcn controlled_exit()
   is hit. Do not exit, but unload ngspice. */
int
ng_exit(int exitstatus, bool immediate, bool quitexit, int ident, void* userdata)
{

    if(quitexit) {
        printf("DNote: Returned quit from library %d with exit status %d\n", ident, exitstatus);
    }
    if(immediate) {
        printf("DNote: Unload ngspice%d\n", ident);
        if (ident == 1) {
            dlclose(ngdllhandle1);
        }  else if (ident == 2) {
            dlclose(ngdllhandle2);
        }  else if (ident == 3) {
            dlclose(ngdllhandle3);
        }
    }

    else {
        printf("DNote: Prepare unloading ngspice%d\n", ident);
        will_unload = true;
    }

    return exitstatus;

}

/* Callback function called from bg thread in ngspice once per accepted data point 
   Set voltage data to in2out1 for transfer from 1 to 2 
   and to in3out2 for transfer from 2 to 3 */
int
ng_data(pvecvaluesall vdata, int numvecs, int ident, void* userdata)
{
    if (ident == 1)
        in2out1 = vdata->vecsa[vecgetnumber1]->creal;
    if (ident == 2)
        in3out2 = vdata->vecsa[vecgetnumber2]->creal;

    return 0;
}


/* Callback function called from bg thread in ngspice once upon intialization
   of the simulation vectors)*/
int
ng_initdata(pvecinfoall intdata, int ident, void* userdata)
{
    int i;
    int vn;
    if (ident == 1) {
        vn = intdata->veccount;
        for (i = 0; i < vn; i++) {
            printf("Vector: %s\n", intdata->vecs[i]->vecname);
            /* find the location of V(out) */
            if (cieq(intdata->vecs[i]->vecname, "out1"))
                vecgetnumber1 = i;
        }
    } else if  (ident == 2) {
        vn = intdata->veccount;
        for (i = 0; i < vn; i++) {
            printf("Vector: %s\n", intdata->vecs[i]->vecname);
            /* find the location of V(out) */
            if (cieq(intdata->vecs[i]->vecname, "out2"))
                vecgetnumber2 = i;
        }
    }
    return 0;
}

/* Set the input voltages for the external voltage sources for
   transfer from 1 --> 2 and 2 --> 3. */
int ng_VSRCData(double* retvoltval, double acttime, char* nodename, int ident, void* userdata)
{
    if (ident == 3)
        *retvoltval = in3out2;
    else if (ident == 2)
        *retvoltval = in2out1;

    return 0;
}

/* Transfer data with currents not used */
int ng_ISRCData(double* retcurrval, double acttime, char* nodename, int ident, void* userdata)
{
    return 0;
}

#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define FABS(a) ((a) > 0 ? (a) : (-a))

int threadcount1 = 0, threadcount2 = 0;
static double newdelta3[3];
static double delt3[3];
static double act3[3];
static int redos3[3];
static int loca3[3];

int ng_SyncData(double acttime, double* deltatime, double olddeltatime,
                int redostep, int ident, int location, void* userdata)
{
    static int retval;
    bool local_ok = false;
    int ii, last_ident;
    int iindex;

    mutex_lock(&sy_cs1);
    iindex = ident - 1;
    threadcount1++;
    /* collect data from all threads */
    delt3[iindex] = *deltatime;
    redos3[iindex] = redostep;
    act3[iindex] = acttime;
    loca3[iindex] = 1;

	if (numthreads == 1) {
        newdelta3[iindex] = delt3[iindex];
		retval = redostep;
		ok1 = ok2 = true;
	}
	else if (threadcount1 == numthreads) {
        /* Simple synchronization: Find the minimum delta time
        for the next time step derived from all threads' deltas and
        impose it on all threads. 
          This is done by the final thread in a time point
        - calculate newdelta as the minum of all deltatime
        - If one redostep is TRUE, return TRUE
        - Set ok to TRUE to release the waiting threads
        - Go directly behind the waiting zone to flag nowait */
        double dmin = 1e30;
        retval = 0;
        for (ii = 0; ii < numthreads; ii++) {
            dmin = MIN(delt3[ii], dmin);
            retval = MAX(redos3[ii], retval);
        }
        for (ii = 0; ii < numthreads; ii++) {
            newdelta3[ii] = dmin;
        }
//		printf("%g   %g   %g\n", act3[0], act3[1], act3[2]);
        last_ident = ident;
        ok1 = true;
    }
	else if  (threadcount1 > threadmax) {
		fprintf(stderr, "Strange out-of-sync\n\n");
	}
    mutex_unlock(&sy_cs1);

    /* collect all threads here and wait */
    while ((!ok1) && (numthreads > 1)) {
#if defined(__MINGW32__) || defined(_MSC_VER)
        Sleep (0);
#else
        usleep (0);
#endif
    }

    mutex_lock(&sy_cs3);
    threadcount1--;
    if (threadcount1 == 0)
        ok1 = false;
    threadcount2++;
    if ((threadcount2 == threadmax) && (ok1 == false)) {
        ok2 = true;
	}
    *deltatime = newdelta3[iindex];
    mutex_unlock(&sy_cs3);

    /* collect all threads here and wait */
    while ((!ok2) && (numthreads > 1)) {
#if defined(__MINGW32__) || defined(_MSC_VER)
        Sleep (0);
#else
        usleep (0);
#endif
    }

    mutex_lock(&sy_cs2);
    threadcount2--;
    if (threadcount2 == 0)
        ok2 = false;
    mutex_unlock(&sy_cs2);

    return retval;
}

static bool* norunsall;
/* Callback function called from ngspice upon starting (returns false) or
  leaving (returns true) the bg thread. */
int
ng_thread_runs(bool noruns, int ident, void* userdata)
{
    int ii;
    bool iruns = true;
    int iindex = ident - 1;
    if (!norunsall)
        norunsall = (bool*)malloc(threadmax*sizeof(bool));

    mutex_lock(&rt_cs);
    norunsall[iindex] = noruns;
    if (noruns) {
        numthreads--;
        ok1 = (threadcount1 == numthreads);
    }

    for (ii = 0; ii < threadmax; ii++)
        iruns = iruns & norunsall[ii];
    no_bg = iruns;
    mutex_unlock(&rt_cs);

    if (noruns)
        printf("lib %d: bg not running\n", ident);
    else
        printf("lib %d: bg running\n", ident);

    return 0;
}


