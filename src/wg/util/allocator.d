// Written in the D programming language.
/**
An allocator representation for compatibility purposes.
Supports `std.experimental.allocator`, GC and `malloc`.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.util.allocator;

import wg.util.traits : isReferenceType;

/**
Allocator representation as a struct.
*/
struct Allocator
{
    /// The allocator
    alias AllocFunc = void* function(size_t bytes, size_t* allocated, shared void* userData) @nogc nothrow;
    /// The deallocator
    alias FreeFunc = void function(void* alloc, size_t bytes, shared void* userData) @nogc nothrow;

    /// Allocator function
    AllocFunc allocFunc;
    /// Deallocator function
    FreeFunc freeFunc;

    /// Pointer to some user data to pass into the allocator/deallocator functions.
    shared void* userData;

    /**
    Allocates some memory using the allocator function.

    Params:
        bytes = Number of bytes to allocate

    Returns:
        The array of memory allocated of length `bytes`.
    */
    void[] allocate(size_t bytes) @nogc nothrow
    {
        void* mem = allocFunc(bytes, &bytes, userData);
        return mem[0 .. bytes];
    }

    /**
    Deallocates a given bit of memory using the deallocator function.

    Only deallocate memory using this function if it was allocated by `allocate`.
    If it was not, behavior is unknown and implementation dependent.

    Params:
        mem = A memory slice allocated by `allocate`.

    Returns:
        If successful.
    */
    bool deallocate(void[] mem) @nogc nothrow
    {
        freeFunc(mem.ptr, mem.length, userData);
        return true;
    }

    /// A helper function to deallocate a class
    bool deallocate(T)(T cls) @nogc nothrow if (is(T == class))
    {
        cls.destroy!false();
        freeFunc(cast(void*)cls, __traits(classInstanceSize, T), userData);
        return true;
    }

    /// A helper function to deallocate a struct
    bool deallocate(T)(T* obj) @nogc nothrow if (is(T == struct))
    {
        obj.destroy!false();
        freeFunc(obj, T.sizeof, userData);
        return true;
    }
}

/**
Make an `Allocator` from an object that conforms to the `std.experimental.allocator` interface.

Params:
    instance = The pre-existing instance (if any).

Returns:
    A copy of an `Allocator` instance that is configured for `Alloc` type.
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
Makes an `Allocator` using C's `malloc` and `free` as the implementation.

Returns:
    A copy of an `Allocator` instance that is configured with `malloc` and `free`.
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
