using LinearAlgebra: Diagonal, diag

"""
    projector([T::Type], x)

"project" `dx` onto type `T` such that it is the same size as `x`. If `T` is not provided,
it is assumed to be the type of `x`.

It's necessary to have `x` to ensure that it's possible to projector e.g. `AbstractZero`s
onto `Array`s -- this wouldn't be possible with type information alone because the neither
`AbstractZero`s nor `T` know what size of `Array` to produce.
""" # TODO change docstring to reflect projecor returns a closure
function projector end

projector(x) = projector(typeof(x), x)

# fallback
function projector(::Type{T}, x::T) where T
    println("to Any")
    project(dx::T) = dx
    project(dx::AbstractZero) = zero(x)
    project(dx::AbstractThunk) = project(unthunk(dx))
    return project
end

# Numbers
function projector(::Type{T}, x::T) where {T<:Real}
    println("to Real")
    project(dx::Real) = T(dx)
    project(dx::Number) = T(real(dx)) # to avoid InexactError
    project(dx::AbstractZero) = zero(x)
    project(dx::AbstractThunk) = project(unthunk(dx))
    return project
end
function projector(::Type{T}, x::T) where {T<:Number}
    println("to Number")
    project(dx::Number) = T(dx)
    project(dx::AbstractZero) = zero(x)
    project(dx::AbstractThunk) = project(unthunk(dx))
    return project
end

# Arrays
function projector(::Type{Array{T, N}}, x::Array{T, N}) where {T, N}
    println("to Array")
    element = zero(eltype(x))
    project(dx::Array{T, N}) = dx # identity
    project(dx::AbstractArray) = project(collect(dx)) # from Diagonal
    project(dx::Array) = projector(element).(dx) # from different element type
    project(dx::AbstractZero) = zero(x)
    project(dx::AbstractThunk) = project(unthunk(dx))
    return project
end

# Tangent
function projector(::Type{<:Tangent}, x)
    println("to Tangent")
    keys = fieldnames(typeof(x))
    project(dx) = Tangent{typeof(x)}(; ((k, getproperty(dx, k)) for k in keys)...)
    return project
end

# Diagonal
function projector(::Type{<:Diagonal{<:Any, V}}, x::Diagonal) where {V}
    println("to Diagonal")
    d = diag(x)
    project(dx::AbstractMatrix) = Diagonal(projector(V, d)(diag(dx)))
    project(dx::Tangent) = Diagonal(projector(V, d)(dx.diag))
    project(dx::AbstractZero) = Diagonal(projector(V, d)(dx))
    project(dx::AbstractThunk) = project(unthunk(dx))
    return project
end

