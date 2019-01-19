module wg.util.allocator;

import wg.util.traits : isReferenceType;

/**
 * A 'hard' allocator struct that supports `std.experimental.allocator`, and can easily interface with C
 */
struct Allocator
{
    alias AllocFunc =  void* function(size_t bytes, size_t* allocated, shared void* userData) @nogc nothrow;
    alias FreeFunc =  void function(void* alloc, size_t bytes, shared void* userData) @nogc nothrow;

    AllocFunc allocFunc;
    FreeFunc freeFunc;
    shared void* userData;

    void[] allocate(size_t bytes) @nogc nothrow
    {
        void* mem = allocFunc(bytes, &bytes, userData);
        return mem[0 .. bytes];
    }

    bool deallocate(void[] mem) @nogc nothrow
    {
        freeFunc(mem.ptr, mem.length, userData);
        return true;
    }
}

/**
 * make an `Allocator` from an object that conforms to the `std.experimental.allocator` interface
 */
Allocator makeAllocator(Alloc)(shared(Alloc) instance = null) if (isReferenceType!Alloc)
{
    static alloc(size_t bytes, size_t* allocated, shared void* userData) @nogc nothrow
    {
        shared Alloc allocator = cast(shared Alloc)userData;
        void[] mem = allocator.allocate(bytes);
        if (allocated)
            *allocated = mem.length;
        return mem.ptr;
    }
    static free(void* alloc, size_t bytes, shared void* userData) @nogc nothrow
    {
        shared(Alloc) allocator = cast(shared(Alloc))userData;
        allocator.deallocate(alloc[0 .. bytes]);
    }

    return Allocator(&alloc, &free, instance);
}
