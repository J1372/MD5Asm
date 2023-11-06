#include <stdio.h>
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

struct MD5
{
    uint32_t hash[4];
};

struct MD5Str
{
    char str[33];
};

// Functions defined in asm.
// Hashes contents by reading from the file descriptor and stores in hash.
extern void md5_hash_file(int fd, struct MD5* hash);
// Using the given hash, stores a hexadecimal representation in md5_str.
extern void md5_get_hash_rep(struct MD5* hash, struct MD5Str* md5_str);

struct ThreadArgs
{
    struct MD5Str* hash_stores; // points at first location the the thread should store results in.
    char** filenames; // points at first filename the thread is responsible for.
    int num_tasks; // number of files the thread should hash.
};

void* hasher_thread(void* thread_arg)
{
    struct ThreadArgs* args = (struct ThreadArgs*) thread_arg;

    for (int i = 0; i < args->num_tasks; ++i)
    {
        struct MD5 md5;
        const char* filename = args->filenames[i];
        struct MD5Str* md5_str = args->hash_stores + i;

        FILE* file = fopen(filename, "rb");
        if (file)
        {
            md5_hash_file(fileno(file), &md5);
            fclose(file);
            md5_get_hash_rep(&md5, md5_str);
        }
        else
        {
            // could not open file
            md5_str->str[0] = '\0';
        }
    }

    return NULL;
}

int main(int argc, char** argv)
{
    if (argc < 2) // ensure at least one file
    {
        return 0;
    }

    char** files = argv + 2;
    int num_files = argc - 2;
    int num_threads = atoi(argv[1]);

    // Check if user provided number of threads in first arg.
    if (num_threads == 0)
    {
        num_threads = 1;
        ++num_files;
        --files;
    }

    // Ensure user provided at least one filename.
    if (num_files <= 0)
        return 0;

    // Limit number of threads to be at most number of files.
    if (num_threads > num_files)
        num_threads = num_files;

    // Allocate space for threads, thread arguments, and result hex strings.
    struct MD5Str* hashes = malloc(sizeof(struct MD5Str) * num_files);
    pthread_t* threads = malloc(sizeof(pthread_t) * num_threads);
    struct ThreadArgs* thread_args = malloc(sizeof(struct ThreadArgs) * num_threads);

    // Compute number of files each thread is responsible for + any leftover files.
    int equal_work = num_files / num_threads;
    int leftover = num_files % num_threads;
    for (int i = 0; i < num_threads; ++i)
    {
        // Calculate work for this thread, handling an extra file if necessary.
        int work = equal_work + (i < leftover);
        // Index of the filename and output which the thread should start at.
        // Start where the previous thread left off.
        int index = equal_work * i + fmin(i, leftover);

        struct ThreadArgs* cur_thread_args = thread_args + i;
        cur_thread_args->hash_stores = hashes + index;
        cur_thread_args->filenames = files + index;
        cur_thread_args->num_tasks = work;

        if (pthread_create(threads + i, NULL, &hasher_thread, cur_thread_args) != 0)
        {
            printf("Could not create thread %d\n", i);
        }
    }

    for (int i = 0; i < num_threads; ++i)
    {
        if (pthread_join(threads[i], NULL) != 0)
        {
            printf("Could not join thread %d\n", i);
        }

    }

    free(threads);
    free(thread_args);

    // print file results in the order they were requested.
    for (int i = 0; i < num_files; ++i)
    {
        const char* filename = files[i];
        const char* hash = hashes[i].str;

        // Print hash result if available.
        if (hash[0] != '\0') 
        {
            printf("%s - %s\n", hash, filename);
        }
        else
        {
            // file was not hashed.
            // Size of md5 hash hex representation is a fixed size - 32.
            printf("Unavailable                      - %s\n", filename);
        }
        
       
    }
    
    free(hashes);

    return 0;
}
