# This file is a part of Julia. License is MIT: https://julialang.org/license

## floating-point functions ##

copysign(x::Float64, y::Float64) = copysign_float(x, y)
copysign(x::Float32, y::Float32) = copysign_float(x, y)
copysign(x::Float32, y::Real) = copysign(x, Float32(y))
copysign(x::Float64, y::Real) = copysign(x, Float64(y))

flipsign(x::Float64, y::Float64) = bitcast(Float64, xor_int(bitcast(UInt64, x), and_int(bitcast(UInt64, y), 0x8000000000000000)))
flipsign(x::Float32, y::Float32) = bitcast(Float32, xor_int(bitcast(UInt32, x), and_int(bitcast(UInt32, y), 0x80000000)))
flipsign(x::Float32, y::Real) = flipsign(x, Float32(y))
flipsign(x::Float64, y::Real) = flipsign(x, Float64(y))

signbit(x::Float64) = signbit(bitcast(Int64, x))
signbit(x::Float32) = signbit(bitcast(Int32, x))
signbit(x::Float16) = signbit(bitcast(Int16, x))

"""
    maxintfloat(T=Float64)

The largest consecutive integer-valued floating-point number that is exactly represented in
the given floating-point type `T` (which defaults to `Float64`).

That is, `maxintfloat` returns the smallest positive integer-valued floating-point number
`n` such that `n+1` is *not* exactly representable in the type `T`.

When an `Integer`-type value is needed, use `Integer(maxintfloat(T))`.
"""
maxintfloat(::Type{Float64}) = 9007199254740992.
maxintfloat(::Type{Float32}) = Float32(16777216.)
maxintfloat(::Type{Float16}) = Float16(2048f0)
maxintfloat(x::T) where {T<:AbstractFloat} = maxintfloat(T)

"""
    maxintfloat(T, S)

The largest consecutive integer representable in the given floating-point type `T` that
also does not exceed the maximum integer representable by the integer type `S`.  Equivalently,
it is the minimum of `maxintfloat(T)` and [`typemax(S)`](@ref).
"""
maxintfloat(::Type{S}, ::Type{T}) where {S<:AbstractFloat, T<:Integer} = min(maxintfloat(S), S(typemax(T)))
maxintfloat() = maxintfloat(Float64)

isinteger(x::AbstractFloat) = (x - trunc(x) == 0)

"""
    round([T,] x, [r::RoundingMode])
    round(x, [r::RoundingMode]; digits::Integer=0, base = 10)
    round(x, [r::RoundingMode]; sigdigits::Integer, base = 10)

Rounds the number `x`.

Without keyword arguments, `x` is rounded to an integer value, returning a value of type
`T`, or of the same type of `x` if no `T` is provided. An [`InexactError`](@ref) will be
thrown if the value is not representable by `T`, similar to [`convert`](@ref).

If the `digits` keyword argument is provided, it rounds to the specified number of digits
after the decimal place (or before if negative), in base `base`.

If the `sigdigits` keyword argument is provided, it rounds to the specified number of
significant digits, in base `base`.

The [`RoundingMode`](@ref) `r` controls the direction of the rounding; the default is
[`RoundNearest`](@ref), which rounds to the nearest integer, with ties (fractional values
of 0.5) being rounded to the nearest even integer. Note that `round` may give incorrect
results if the global rounding mode is changed (see [`rounding`](@ref)).

# Examples
```jldoctest
julia> round(1.7)
2.0

julia> round(Int, 1.7)
2

julia> round(1.5)
2.0

julia> round(2.5)
2.0

julia> round(pi; digits=2)
3.14

julia> round(pi; digits=3, base=2)
3.125

julia> round(123.456; sigdigits=2)
120.0

julia> round(357.913; sigdigits=4, base=2)
352.0
```

!!! note
    Rounding to specified digits in bases other than 2 can be inexact when
    operating on binary floating point numbers. For example, the [`Float64`](@ref)
    value represented by `1.15` is actually *less* than 1.15, yet will be
    rounded to 1.2.

    # Examples
    ```jldoctest; setup = :(using Printf)
    julia> x = 1.15
    1.15

    julia> @sprintf "%.20f" x
    "1.14999999999999991118"

    julia> x < 115//100
    true

    julia> round(x, digits=1)
    1.2
    ```

# Extensions

To extend `round` to new numeric types, it is typically sufficient to define `Base.round(x::NewType, r::RoundingMode)`.
"""
round(T::Type, x)

function round(::Type{T}, x::AbstractFloat, r::RoundingMode) where {T<:Integer}
    r != RoundToZero && (x = round(x,r))
    trunc(T, x)
end

# NOTE: this relies on the current keyword dispatch behaviour (#9498).
function round(x::Real, r::RoundingMode=RoundNearest;
               digits::Union{Nothing,Integer}=nothing, sigdigits::Union{Nothing,Integer}=nothing, base::Union{Nothing,Integer}=nothing)
    if digits === nothing
        if sigdigits === nothing
            if base === nothing
                # avoid recursive calls
                throw(MethodError(round, (x,r)))
            else
                round(x,r)
                # or throw(ArgumentError("`round` cannot use `base` argument without `digits` or `sigdigits` arguments."))
            end
        else
            isfinite(x) || return float(x)
            _round_sigdigits(x, r, sigdigits, base === nothing ? 10 : base)
        end
    else
        if sigdigits === nothing
            isfinite(x) || return float(x)
            _round_digits(x, r, digits, base === nothing ? 10 : base)
        else
            throw(ArgumentError("`round` cannot use both `digits` and `sigdigits` arguments."))
        end
    end
end

trunc(x::Real; kwargs...) = round(x, RoundToZero; kwargs...)
floor(x::Real; kwargs...) = round(x, RoundDown; kwargs...)
ceil(x::Real; kwargs...)  = round(x, RoundUp; kwargs...)

round(x::Integer, r::RoundingMode) = x

# round x to multiples of 1/invstep
function _round_invstep(x, invstep, r::RoundingMode)
    y = round(x * invstep, r) / invstep
    if !isfinite(y)
        return x
    end
    return y
end

# round x to multiples of 1/(invstepsqrt^2)
# Using square root of step prevents overflowing
function _round_invstepsqrt(x, invstepsqrt, r::RoundingMode)
    y = round((x * invstepsqrt) * invstepsqrt, r) / invstepsqrt / invstepsqrt
    if !isfinite(y)
        return x
    end
    return y
end

# round x to multiples of step
function _round_step(x, step, r::RoundingMode)
    # TODO: use div with rounding mode
    y = round(x / step, r) * step
    if !isfinite(y)
        if x > 0
            return (r == RoundUp ? oftype(x, Inf) : zero(x))
        elseif x < 0
            return (r == RoundDown ? -oftype(x, Inf) : -zero(x))
        else
            return x
        end
    end
    return y
end

function _round_digits(x, r::RoundingMode, digits::Integer, base)
    fx = float(x)
    if digits >= 0
        invstep = oftype(fx, base)^digits
        if isfinite(invstep)
            return _round_invstep(fx, invstep, r)
        else
            invstepsqrt = oftype(fx, base)^oftype(fx, digits/2)
            return _round_invstepsqrt(fx, invstepsqrt, r)
        end
    else
        step = oftype(fx, base)^-digits
        return _round_step(fx, step, r)
    end
end

hidigit(x::Integer, base) = ndigits0z(x, base)
function hidigit(x::AbstractFloat, base)
    iszero(x) && return 0
    if base == 10
        return 1 + floor(Int, log10(abs(x)))
    elseif base == 2
        return 1 + exponent(x)
    else
        return 1 + floor(Int, log(base, abs(x)))
    end
end
hidigit(x::Real, base) = hidigit(float(x), base)

function _round_sigdigits(x, r::RoundingMode, sigdigits::Integer, base)
    h = hidigit(x, base)
    _round_digits(x, r, sigdigits-h, base)
end

# C-style round
function round(x::AbstractFloat, ::RoundingMode{:NearestTiesAway})
    y = trunc(x)
    ifelse(x==y,y,trunc(2*x-y))
end
# Java-style round
function round(x::T, ::RoundingMode{:NearestTiesUp}) where {T <: AbstractFloat}
    copysign(floor((x + (T(0.25) - eps(T(0.5)))) + (T(0.25) + eps(T(0.5)))), x)
end

# isapprox: approximate equality of numbers
"""
    isapprox(x, y; atol::Real=0, rtol::Real=atol>0 ? 0 : √eps, nans::Bool=false[, norm::Function])

Inexact equality comparison. Two numbers compare equal if their relative distance *or* their
absolute distance is within tolerance bounds: `isapprox` returns `true` if
`norm(x-y) <= max(atol, rtol*max(norm(x), norm(y)))`. The default `atol` is zero and the
default `rtol` depends on the types of `x` and `y`. The keyword argument `nans` determines
whether or not NaN values are considered equal (defaults to false).

For real or complex floating-point values, if an `atol > 0` is not specified, `rtol` defaults to
the square root of [`eps`](@ref) of the type of `x` or `y`, whichever is bigger (least precise).
This corresponds to requiring equality of about half of the significant digits. Otherwise,
e.g. for integer arguments or if an `atol > 0` is supplied, `rtol` defaults to zero.

The `norm` keyword defaults to `abs` for numeric `(x,y)` and to `LinearAlgebra.norm` for
arrays (where an alternative `norm` choice is sometimes useful).
When `x` and `y` are arrays, if `norm(x-y)` is not finite (i.e. `±Inf`
or `NaN`), the comparison falls back to checking whether all elements of `x` and `y` are
approximately equal component-wise.

The binary operator `≈` is equivalent to `isapprox` with the default arguments, and `x ≉ y`
is equivalent to `!isapprox(x,y)`.

Note that `x ≈ 0` (i.e., comparing to zero with the default tolerances) is
equivalent to `x == 0` since the default `atol` is `0`.  In such cases, you should either
supply an appropriate `atol` (or use `norm(x) ≤ atol`) or rearrange your code (e.g.
use `x ≈ y` rather than `x - y ≈ 0`).   It is not possible to pick a nonzero `atol`
automatically because it depends on the overall scaling (the "units") of your problem:
for example, in `x - y ≈ 0`, `atol=1e-9` is an absurdly small tolerance if `x` is the
[radius of the Earth](https://en.wikipedia.org/wiki/Earth_radius) in meters,
but an absurdly large tolerance if `x` is the
[radius of a Hydrogen atom](https://en.wikipedia.org/wiki/Bohr_radius) in meters.

!!! compat "Julia 1.6"
    Passing the `norm` keyword argument when comparing numeric (non-array) arguments
    requires Julia 1.6 or later.

# Examples
```jldoctest
julia> isapprox(0.1, 0.15; atol=0.05)
true

julia> isapprox(0.1, 0.15; rtol=0.34)
true

julia> isapprox(0.1, 0.15; rtol=0.33)
false

julia> 0.1 + 1e-10 ≈ 0.1
true

julia> 1e-10 ≈ 0
false

julia> isapprox(1e-10, 0, atol=1e-8)
true

julia> isapprox([10.0^9, 1.0], [10.0^9, 2.0]) # using `norm`
true
```
"""
function isapprox(x::Number, y::Number;
                  atol::Real=0, rtol::Real=rtoldefault(x,y,atol),
                  nans::Bool=false, norm::Function=abs)
    x == y || (isfinite(x) && isfinite(y) && norm(x-y) <= max(atol, rtol*max(norm(x), norm(y)))) || (nans && isnan(x) && isnan(y))
end

"""
    isapprox(x; kwargs...) / ≈(x; kwargs...)

Create a function that compares its argument to `x` using `≈`, i.e. a function equivalent to `y -> y ≈ x`.

The keyword arguments supported here are the same as those in the 2-argument `isapprox`.

!!! compat "Julia 1.5"
    This method requires Julia 1.5 or later.
"""
isapprox(y; kwargs...) = x -> isapprox(x, y; kwargs...)

const ≈ = isapprox
"""
    x ≉ y

This is equivalent to `!isapprox(x,y)` (see [`isapprox`](@ref)).
"""
≉(args...; kws...) = !≈(args...; kws...)

# default tolerance arguments
rtoldefault(::Type{T}) where {T<:AbstractFloat} = sqrt(eps(T))
rtoldefault(::Type{<:Real}) = 0
function rtoldefault(x::Union{T,Type{T}}, y::Union{S,Type{S}}, atol::Real) where {T<:Number,S<:Number}
    rtol = max(rtoldefault(real(T)),rtoldefault(real(S)))
    return atol > 0 ? zero(rtol) : rtol
end

# fused multiply-add

"""
    fma(x, y, z)

Computes `x*y+z` without rounding the intermediate result `x*y`. On some systems this is
significantly more expensive than `x*y+z`. `fma` is used to improve accuracy in certain
algorithms. See [`muladd`](@ref).
"""
function fma end
function fma_emulated(a::Float32, b::Float32, c::Float32)::Float32
    ab = Float64(a) * b
    res = ab+c
    reinterpret(UInt64, res)&0x1fff_ffff!=0x1000_0000 && return res
    # yes error compensation is necessary. It sucks
    reslo = abs(c)>abs(ab) ? ab-(res - c) : c-(res - ab)
    res = iszero(reslo) ? res : (signbit(reslo) ? prevfloat(res) : nextfloat(res))
    return res
end

""" Splits a Float64 into a hi bit and a low bit where the high bit has 27 trailing 0s and the low bit has 26 trailing 0s"""
@inline function splitbits(x::Float64)
    hi = reinterpret(Float64, reinterpret(UInt64, x) & 0xffff_ffff_f800_0000)
    return hi, x-hi
end

@inline function twomul(a::Float64, b::Float64)
    ahi, alo = splitbits(a)
    bhi, blo = splitbits(b)
    abhi = a*b
    blohi, blolo = splitbits(blo)
    ablo = alo*blohi - (((abhi - ahi*bhi) - alo*bhi) - ahi*blo) + blolo*alo
    return abhi, ablo
end

function fma_emulated(a::Float64, b::Float64,c::Float64)
    abhi, ablo = twomul(a,b)
    if !isfinite(abhi+c) || isless(abs(abhi), nextfloat(0x1p-969)) || issubnormal(a) || issubnormal(b)
        (isfinite(a) && isfinite(b) && isfinite(c)) || return abhi+c
        (iszero(a) || iszero(b)) && return abhi+c
        bias = exponent(a) + exponent(b)
        c_denorm = ldexp(c, -bias)
        if isfinite(c_denorm)
            # rescale a and b to [1,2), equivalent to ldexp(a, -exponent(a))
            issubnormal(a) && (a *= 0x1p52)
            issubnormal(b) && (b *= 0x1p52)
            a = reinterpret(Float64, (reinterpret(UInt64, a) & 0x800fffffffffffff) | 0x3ff0000000000000)
            b = reinterpret(Float64, (reinterpret(UInt64, b) & 0x800fffffffffffff) | 0x3ff0000000000000)
            c = c_denorm
            abhi, ablo = twomul(a,b)
            r = abhi+c
            s = (abs(abhi) > abs(c)) ? (abhi-r+c+ablo) : (c-r+abhi+ablo)
            sumhi = r+s
            # If result is subnormal, ldexp will cause double rounding because subnormals have fewer mantisa bits.
            # As such, we need to check whether round to even would lead to double rounding and manually round sumhi to avoid it.
            if issubnormal(ldexp(sumhi, bias))
                sumlo = r-sumhi+s
                bits_lost = -bias-exponent(sumhi)-1022
                sumhiInt = reinterpret(UInt64, sumhi)
                if (bits_lost != 1) ⊻ (sumhiInt&1 == 1)
                    sumhi = nextfloat(sumhi, cmp(sumlo,0))
                end
            end
            return ldexp(sumhi, bias)
        end
        isinf(abhi) && signbit(c) == signbit(a*b) && return abhi
        # fall through
    end
    r = abhi+c
    s = (abs(abhi) > abs(c)) ? (abhi-r+c+ablo) : (c-r+abhi+ablo)
    return r+s
end
fma_llvm(x::Float32, y::Float32, z::Float32) = fma_float(x, y, z)
fma_llvm(x::Float64, y::Float64, z::Float64) = fma_float(x, y, z)

# Disable LLVM's fma if it is incorrect, e.g. because LLVM falls back
# onto a broken system libm; if so, use a software emulated fma
fma(x::Float32, y::Float32, z::Float32) = Core.Intrinsics.have_fma(Float32) ? fma_llvm(x,y,z) : fma_emulated(x,y,z)
fma(x::Float64, y::Float64, z::Float64) = Core.Intrinsics.have_fma(Float64) ? fma_llvm(x,y,z) : fma_emulated(x,y,z)

function fma(a::Float16, b::Float16, c::Float16)
    Float16(muladd(Float32(a), Float32(b), Float32(c))) #don't use fma if the hardware doesn't have it.
end

# This is necessary at least on 32-bit Intel Linux, since fma_llvm may
# have called glibc, and some broken glibc fma implementations don't
# properly restore the rounding mode
Rounding.setrounding_raw(Float32, Rounding.JL_FE_TONEAREST)
Rounding.setrounding_raw(Float64, Rounding.JL_FE_TONEAREST)
