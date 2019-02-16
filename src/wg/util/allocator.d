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

    // helpers to destroy objects
    bool deallocate(T)(T cls) @nogc nothrow if (is(T == class))
    {
        cls.destroy!false();
        freeFunc(cast(void*)cls, __traits(classInstanceSize, T), userData);
        return true;
    }
    bool deallocate(T)(T* obj) @nogc nothrow if (is(T == struct))
    {
        obj.destroy!false();
        freeFunc(obj, T.sizeof, userData);
        return true;
    }
}

/**
 * Make an `Allocator` from an object that conforms to the `std.experimental.allocator` interface
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

/**
 * Get an allocator that uses the C malloc()/free() functions.
 */
Allocator* getMallocAllocator()
{
    import core.stdc.stdlib : malloc, free;

    static void* memAlloc(size_t bytes, size_t* allocated, shared void*) @nogc nothrow
    {
        void* mem = malloc(bytes);
        if (allocated)
            *allocated = bytes;
        return mem;
    }
    static void memFree(void* alloc, size_t, shared void*) @nogc nothrow
    {
        free(alloc);
    }

    __gshared Allocator instance = Allocator(&memAlloc, &memFree, null);

    return &instance;
}


package(wg):

// this is a hack, strictly for internal use, which returns a GC allocator in a `@nogc` container
// it can be used by GC allocating overloads to call through to `@nogc` implementation functions
Allocator* getGcAllocator()
{
    static void* gcAlloc(size_t bytes, size_t* allocated, shared void* userData) nothrow @trusted
    {
        void[] mem = new void[bytes];
        if (allocated)
            *allocated = mem.length;
        return mem.ptr;
    }

    __gshared Allocator instance = Allocator(cast(Allocator.AllocFunc)&gcAlloc, (void*, size_t, shared void*) {}, null);

    return &instance;
}
