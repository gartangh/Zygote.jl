using NNlib
import NNlib: softmax, ∇softmax, logsoftmax, ∇logsoftmax, conv, ∇conv_data, maxpool, meanpool, σ, relu, batched_mul, batched_adjoint

@adjoint function Base.Broadcast.broadcasted(::typeof(relu), x::Numeric)
  relu.(x), Δ -> (nothing, ifelse.(x .> 0, Δ, zero.(x)))
end

@adjoint function σ(x::Real)
    y = σ(x)
    return y, Δ -> (Δ * y * (1 - y),)
end

@adjoint softmax(xs; dims=1) = softmax(xs, dims=dims), Δ -> (∇softmax(Δ, xs, dims=dims),)

@adjoint logsoftmax(xs; dims=1) = logsoftmax(xs, dims=dims), Δ -> (∇logsoftmax(Δ, xs, dims=dims),)

@adjoint NNlib.DenseConvDims(args...; kwargs...) = NNlib.DenseConvDims(args...; kwargs...), _ -> nothing
# @adjoint NNlib.DepthwiseConvDims(args...; kwargs...) = NNlib.DepthwiseConvDims(args...; kwargs...), _ -> nothing
@adjoint NNlib.PoolDims(args...; kwargs...) = NNlib.PoolDims(args...; kwargs...), _ -> nothing

colmajor(x) = colmajor(MemoryLayout(typeof(x)), x)
colmajor(_, x) = convert(Array, x)
colmajor(::AbstractColumnMajor, x) = x


@adjoint conv(x, w, cdims; kw...) =
  conv(x, w, cdims; kw...),
    Δ -> begin
       Δ = colmajor(Δ)
       return (
           NNlib.∇conv_data(Δ, w, cdims; kw...),
           NNlib.∇conv_filter(x, Δ, cdims; kw...),
           nothing,
       )
   end

@adjoint ∇conv_data(x, w, cdims; kw...) =
  ∇conv_data(x, w, cdims; kw...),
    Δ -> begin
       Δ = colmajor(Δ)
       return (
           NNlib.conv(Δ, w, cdims; kw...),
           NNlib.∇conv_filter(Δ, x, cdims; kw...),
           nothing,
       )
   end

# @adjoint depthwiseconv(x, w, cdims; kw...) =
#   depthwiseconv(x, w, cdims; kw...),
#     Δ -> begin
#        return (
#            NNlib.∇depthwiseconv_data(Δ, w, cdims; kw...),
#            NNlib.∇depthwiseconv_filter(x, Δ, cdims; kw...),
#            nothing,
#        )
#    end
#
# @adjoint ∇depthwiseconv_data(x, w, cdims; kw...) =
#   ∇depthwiseconv_data(x, w, cdims; kw...),
#     Δ -> begin
#        return (
#            NNlib.depthwiseconv(Δ, w, cdims; kw...),
#            NNlib.∇depthwiseconv_filter(Δ, x, cdims; kw...),
#            nothing,
#        )
#    end

@adjoint function maxpool(x, pdims::NNlib.PoolDims; kw...)
  y = maxpool(x, pdims; kw...)
  y, Δ -> (NNlib.∇maxpool(Δ, y, x, pdims; kw...), nothing)
end

@adjoint function meanpool(x, pdims::NNlib.PoolDims; kw...)
  y = meanpool(x, pdims; kw...)
  y, Δ -> (NNlib.∇meanpool(Δ, y, x, pdims; kw...), nothing)
end

@adjoint function batched_mul(A, B)
    C = batched_mul(A, B)
    C, Δ -> (batched_mul(Δ, batched_adjoint(B)), batched_mul(batched_adjoint(A), Δ))
end
