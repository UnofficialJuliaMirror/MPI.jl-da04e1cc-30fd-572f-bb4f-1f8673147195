function Dims_create!(nnodes::Integer, ndims::Integer, dims::MPIBuffertype{T}) where {T <: Integer}
    # int MPI_Dims_create(int nnodes, int ndims, int dims[])
    @mpichk ccall((:MPI_Dims_create, libmpi), Cint,
                  (Cint, Cint, Ptr{Cint}), nnodes, ndims, dims)
end

function Dims_create!(nnodes::Integer, dims::AbstractArray{T,N}) where {T<:Integer, N}
    cdims = Cint.(dims[:])
    ndims = length(cdims)
    Dims_create!(nnodes, ndims, cdims)
    dims[:] .= cdims
end

function Cart_create(comm_old::Comm, ndims::Integer, dims::MPIBuffertype{Cint}, periods::MPIBuffertype{Cint}, reorder)
    comm_cart = Comm()
    # int MPI_Cart_create(MPI_Comm comm_old, int ndims, const int dims[],
    #                     const int periods[], int reorder, MPI_Comm *comm_cart)
    @mpichk ccall((:MPI_Cart_create, libmpi), Cint,
                  (MPI_Comm, Cint, Ptr{Cint}, Ptr{Cint}, Cint, Ptr{MPI_Comm}),
                  comm_old, ndims, dims, periods, reorder, comm_cart)
    if comm_cart.val != MPI_COMM_NULL
        refcount_inc()
        finalizer(free, comm_cart)
    end
    comm_cart
end

function Cart_create(comm_old::Comm, dims::AbstractArray{T,N}, periods::Array{T,N}, reorder) where T <: Integer where N
    cdims    = Cint.(dims[:])
    cperiods = Cint.(periods[:])
    ndims    = length(cdims)
    Cart_create(comm_old, ndims, cdims, cperiods, reorder)
end

"""
    Cart_get(comm::Comm, maxdims::Integer)

Obtain information on the Cartesian topology of dimension `maxdims` underlying the 
communicator `comm`. This is specified by two `Cint` arrays of `maxdims` elements
for the number of processes and periodicity properties along each Cartesian dimension. 
A third `Cint` array is returned, containing the Cartesian coordinates of the calling process.
"""
function Cart_get(comm::Comm, maxdims::Integer)
    # preallocate with nontrivial values
    dims    = Cint[-1 for i = 1:maxdims]
    periods = Cint[-1 for i = 1:maxdims]
    coords  = Cint[-1 for i = 1:maxdims]
    # int MPI_Cart_get(MPI_Comm comm, int maxdims, int dims[], int periods[], int coords[])
    @mpichk ccall((:MPI_Cart_get, libmpi), Cint,
                  (MPI_Comm, Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}),
                  comm, maxdims, dims, periods, coords)
    return dims, periods, coords
end

"""
    Cartdim_get(comm::Comm)

Return number of dimensions of the Cartesian topology associated with the communicator `comm`.
"""
function Cartdim_get(comm::Comm)
    dims    = Cint[0]
    # int MPI_Cartdim_get(MPI_Comm comm, int *ndims)
    @mpichk ccall((:MPI_Cartdim_get, libmpi), Cint,
                  (MPI_Comm, Ptr{Cint}),
                  comm, dims)
    return Int(dims[1])
end

function Cart_coords!(comm::Comm, rank::Integer, maxdims::Integer, coords::MPIBuffertype{Cint})
    # int MPI_Cart_coords(MPI_Comm comm, int rank, int maxdims, int coords[])
    @mpichk ccall((:MPI_Cart_coords, libmpi), Cint,
                  (MPI_Comm, Cint, Cint, Ptr{Cint}),
                  comm, rank, maxdims, coords)
end

function Cart_coords(comm::Comm, maxdims::Integer)
    ccoords = Vector{Cint}(undef, maxdims)
    rank    = Comm_rank(comm)
    Cart_coords!(comm, rank, maxdims, ccoords)
    Int.(ccoords)
end

function Cart_shift(comm::Comm, direction::Integer, disp::Integer)
    rank_source = Ref{Cint}()
    rank_dest   = Ref{Cint}()
    # int MPI_Cart_shift(MPI_Comm comm, int direction, int disp,
    #                    int *rank_source, int *rank_dest)
    @mpichk ccall((:MPI_Cart_shift, libmpi), Cint,
                  (MPI_Comm, Cint, Cint, Ptr{Cint}, Ptr{Cint}),
                  comm, direction, disp, rank_source, rank_dest)
    Int(rank_source[]), Int(rank_dest[])
end

function Cart_sub(comm::Comm, remain_dims)
    comm_sub = Comm()
    remain_dims = [Cint(dim) for dim in remain_dims]
    # int MPI_Cart_sub(MPI_Comm comm, const int remain_dims[], MPI_Comm *comm_new)
    @mpichk ccall((:MPI_Cart_sub, libmpi), Cint,
                  (MPI_Comm, Ptr{Cint}, Ptr{MPI_Comm}),
                  comm, remain_dims, comm_sub)
    if comm_sub.val != MPI_COMM_NULL
        refcount_inc()
        finalizer(free, comm_sub)
    end
    comm_sub
end
