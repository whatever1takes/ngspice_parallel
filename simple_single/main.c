/*
 * Simple Single Thread NGSpice Test
 * Just run one netlist with ngspice and show all native logs
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

// NGSpice shared library interface
#include "sharedspice.h"

// Callback function for ngspice output - show ALL native logs
int ng_getchar(char* outputreturn, int ident, void* userdata)
{
    printf("%s\n", outputreturn);
    fflush(stdout);
    return 0;
}

// Callback function for ngspice status - show ALL native logs
int ng_getstat(char* outputreturn, int ident, void* userdata)
{
    printf("STATUS: %s\n", outputreturn);
    fflush(stdout);
    return 0;
}

// Callback function for thread status
int ng_thread_runs(bool noruns, int ident, void* userdata)
{
    if (noruns) {
        printf("THREAD: Simulation COMPLETED\n");
    } else {
        printf("THREAD: Simulation RUNNING\n");
    }
    fflush(stdout);
    return 0;
}

// Callback function for exit
int ng_exit(int exitstatus, bool immediate, bool quitexit, int ident, void* userdata)
{
    printf("EXIT: NGSpice exit with status %d\n", exitstatus);
    fflush(stdout);
    return exitstatus;
}

int main()
{
    printf("========================================\n");
    printf("Simple Single Thread NGSpice Test\n");
    printf("========================================\n");
    
    // Initialize ngspice
    printf("Initializing NGSpice...\n");
    int result = ngSpice_Init(ng_getchar, ng_getstat, ng_exit, NULL, NULL, ng_thread_runs, NULL);
    if (result != 0) {
        printf("ERROR: Failed to initialize ngspice (error: %d)\n", result);
        return 1;
    }
    
    printf("NGSpice initialized successfully\n");
    printf("========================================\n");
    
    // Load circuit file
    const char* circuit_file = "./test_circuit.cir";
    printf("Loading circuit: %s\n", circuit_file);
    printf("========================================\n");
    
    char source_cmd[256];
    snprintf(source_cmd, sizeof(source_cmd), "source %s", circuit_file);
    
    result = ngSpice_Command(source_cmd);
    if (result != 0) {
        printf("ERROR: Failed to load circuit (error: %d)\n", result);
        return 1;
    }
    
    printf("========================================\n");
    printf("Starting simulation...\n");
    printf("========================================\n");
    
    // Run simulation
    result = ngSpice_Command("run");
    if (result != 0) {
        printf("ERROR: Failed to run simulation (error: %d)\n", result);
        return 1;
    }
    
    printf("========================================\n");
    printf("Simulation completed successfully!\n");
    printf("========================================\n");
    
    return 0;
}
