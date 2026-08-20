#include <stdio.h>
#include <stdexcept>
#include <objc/runtime.h>

__attribute__((objc_root_class))
@interface ExceptionBase
{
    Class isa;
}
+ (id)new;
@end

@interface ExceptionDerived : ExceptionBase @end

@implementation ExceptionBase
+ (id)new { return class_createInstance(self, 0); }
@end
@implementation ExceptionDerived @end

struct CleanupGuard
{
    int *count;
    ~CleanupGuard() { ++*count; }
};

static bool objc_matching_and_rethrowing(void)
{
    id object = [ExceptionDerived new];
    bool matched = false;
    @try
    {
        @try
        {
            @throw object;
        }
        @catch (id caught)
        {
            if (caught == object)
                @throw;
        }
    }
    @catch (ExceptionBase *caught)
    {
        matched = caught == object;
    }
    object_dispose(object);
    return matched;
}

static bool objc_catch_nil(void)
{
    bool caught = false;
    @try
    {
        @throw (id)nil;
    }
    @catch (id object)
    {
        caught = object == nil;
    }
    return caught;
}

static bool cpp_catches_objective_c(void)
{
    id object = [ExceptionDerived new];
    bool caught = false;
    try
    {
        @throw object;
    }
    catch (ExceptionBase *exception)
    {
        caught = exception == object;
    }
    object_dispose(object);
    return caught;
}

static bool objective_c_does_not_catch_cpp(void)
{
    bool caughtByCpp = false;
    try
    {
        @try
        {
            throw std::runtime_error("C++ exception");
        }
        @catch (id)
        {
            return false;
        }
    }
    catch (const std::runtime_error &exception)
    {
        caughtByCpp = exception.what()[0] == 'C';
    }
    return caughtByCpp;
}

static bool cpp_catches_cpp(void)
{
    bool caught = false;
    try
    {
        throw std::runtime_error("C++ exception");
    }
    catch (const std::runtime_error &exception)
    {
        caught = exception.what()[0] == 'C';
    }
    return caught;
}

static bool objective_c_unwind_runs_cpp_cleanup(void)
{
    int cleanups = 0;
    id object = [ExceptionDerived new];
    bool caught = false;
    @try
    {
        CleanupGuard guard = {&cleanups};
        @throw object;
    }
    @catch (ExceptionBase *exception)
    {
        caught = exception == object;
    }
    object_dispose(object);
    return caught && cleanups == 1;
}

static bool nested_objective_c_rethrow(void)
{
    id object = [ExceptionDerived new];
    bool caught = false;
    @try
    {
        @try { @throw object; }
        @catch (ExceptionDerived *) { @throw; }
    }
    @catch (ExceptionBase *exception)
    {
        caught = exception == object;
    }
    object_dispose(object);
    return caught;
}

int main(void)
{
    const bool checks[] = {
        objc_catch_nil(),
        objc_matching_and_rethrowing(),
        cpp_catches_objective_c(),
        objective_c_does_not_catch_cpp(),
        cpp_catches_cpp(),
        objective_c_unwind_runs_cpp_cleanup(),
        nested_objective_c_rethrow(),
    };
    int passed = 0;
    for (bool check : checks)
        passed += check;
    printf("objc-exceptions-integration: %d/%zu\n", passed,
           sizeof(checks) / sizeof(checks[0]));
    return passed == (int)(sizeof(checks) / sizeof(checks[0])) ? 0 : 1;
}
