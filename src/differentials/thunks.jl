abstract type AbstractThunk <: AbstractTangent end

struct MutateThunkException <: Exception end

function Base.showerror(io::IO, e::MutateThunkException)
    print(io, "Tried to mutate a thunk, this is not supported. `unthunk` it first.")
    return nothing
end

Base.Broadcast.broadcastable(x::AbstractThunk) = broadcastable(unthunk(x))

@inline function Base.iterate(x::AbstractThunk)
    val = unthunk(x)
    element, state = iterate(val)
    return element, (val, state)
end

@inline function Base.iterate(::AbstractThunk, (underlying_object, state))
    next = iterate(underlying_object, state)
    next === nothing && return nothing
    element, new_state = next
    return element, (underlying_object, new_state)
end

"""
    @thunk expr

Define a [`Thunk`](@ref) wrapping the `expr`, to lazily defer its evaluation.
"""
macro thunk(body)
    # Basically `:(Thunk(() -> $(esc(body))))` but use the location where it is defined.
    # so we get useful stack traces if it errors.
    func = Expr(:->, Expr(:tuple), Expr(:block, __source__, body))
    return :(Thunk($(esc(func))))
end

"""
    unthunk(x)

On `AbstractThunk`s this removes 1 layer of thunking.
On any other type, it is the identity operation.
"""
@inline unthunk(x) = x

Base.conj(x::AbstractThunk) = @thunk(conj(unthunk(x)))
Base.adjoint(x::AbstractThunk) = @thunk(adjoint(unthunk(x)))
Base.transpose(x::AbstractThunk) = @thunk(transpose(unthunk(x)))

#####
##### `Thunk`
#####

"""
    Thunk(()->v)
A thunk is a deferred computation.
It wraps a zero argument closure that when invoked returns a differential.
`@thunk(v)` is a macro that expands into `Thunk(()->v)`.

To evaluate the wrapped closure, call [`unthunk`](@ref) which is a no-op when the
argument is not a `Thunk`.

```jldoctest
julia> t = @thunk(3)
Thunk(var"#4#5"())

julia> unthunk(t)
3
```

### When to `@thunk`?
When writing `rrule`s (and to a lesser exent `frule`s), it is important to `@thunk`
appropriately.
Propagation rules that return multiple derivatives may not have all deriviatives used.
 By `@thunk`ing the work required for each derivative, they then compute only what is needed.

#### How do thunks prevent work?
If we have `res = pullback(...) = @thunk(f(x)), @thunk(g(x))`
then if we did `dx + res[1]` then only `f(x)` would be evaluated, not `g(x)`.
Also if we did `ZeroTangent() * res[1]` then the result would be `ZeroTangent()` and `f(x)` would not be evaluated.

#### So why not thunk everything?
`@thunk` creates a closure over the expression, which (effectively) creates a `struct`
with a field for each variable used in the expression, and call overloaded.

Do not use `@thunk` if this would be equal or more work than actually evaluating the expression itself.
This is commonly the case for scalar operators.

For more details see the manual section [on using thunks effectively](http://www.juliadiff.org/ChainRulesCore.jl/dev/writing_good_rules.html#Use-Thunks-appropriately-1)
"""
struct Thunk{F} <: AbstractThunk
    f::F
end

@inline unthunk(x::Thunk) = x.f()

Base.show(io::IO, x::Thunk) = print(io, "Thunk($(repr(x.f)))")

Base.convert(::Type{<:Thunk}, a::AbstractZero) = @thunk(a)


"""
    InplaceableThunk(add!::Function, val::Thunk)

A wrapper for a `Thunk`, that allows it to define an inplace `add!` function.

`add!` should be defined such that: `ithunk.add!(Δ) = Δ .+= ithunk.val`
but it should do this more efficently than simply doing this directly.
(Otherwise one can just use a normal `Thunk`).

Most operations on an `InplaceableThunk` treat it just like a normal `Thunk`;
and destroy its inplacability.
"""
struct InplaceableThunk{T<:Thunk,F} <: AbstractThunk
    add!::F
    val::T
end

unthunk(x::InplaceableThunk) = unthunk(x.val)

function Base.show(io::IO, x::InplaceableThunk)
    return print(io, "InplaceableThunk($(repr(x.val)), $(repr(x.add!)))")
end
