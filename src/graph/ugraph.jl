#
# This file is a part of graphmol.jl
# Licensed under the MIT License http://opensource.org/licenses/MIT
#

export
    Node,
    Edge,
    UGraph,
    GMapUGraph,
    GVectorUGraph,
    connect,
    getnode,
    getedge,
    nodesiter,
    edgesiter,
    nodekeys,
    edgekeys,
    neighbors,
    nodecount,
    edgecount,
    updatenode!,
    updateedge!,
    unlinknode!,
    unlinkedge!,
    similarmap


struct Node <: AbstractNode
    attr::Dict
end

Node() = Node(Dict())


struct Edge <: AbstractEdge
    u::Int
    v::Int
    attr::Dict
end

Edge(u, v) = Edge(u, v, Dict())
connect(e::Edge, u, v) = Edge(u, v, e.attr)


struct GMapUGraph{N<:AbstractNode,E<:AbstractEdge} <: MapUGraph
    nodes::Dict{Int,N}
    edges::Dict{Int,E}
    adjacency::Dict{Int,Dict{Int,Int}}

    function GMapUGraph{N,E}() where {N<:AbstractNode,E<:AbstractEdge}
        new(Dict(), Dict(), Dict())
    end
end

function GMapUGraph(nodes::AbstractArray{Int},
                        edges::AbstractArray{Tuple{Int,Int}})
    graph = GMapUGraph{Node,Edge}()
    for node in nodes
        updatenode!(graph, Node(), node)
    end
    for (i, edge) in enumerate(edges)
        updateedge!(graph, Edge(edge...), i)
    end
    graph
end


struct GVectorUGraph{N<:AbstractNode,E<:AbstractEdge} <: VectorUGraph
    nodes::Vector{N}
    edges::Vector{E}
    adjacency::Vector{Dict{Int,Int}}
end

function GVectorUGraph(size::Int, edges::AbstractArray{Tuple{Int,Int}})
    # do not use `fill`
    ns = [Node() for i in 1:size]
    adj = [Dict() for i in 1:size]
    es = []
    for (i, (u, v)) in enumerate(edges)
        push!(es, Edge(u, v))
        adj[u][v] = i
        adj[v][u] = i
    end
    GVectorUGraph{Node,Edge}(ns, es, adj)
end

function GVectorUGraph{N,E}(graph::GMapUGraph{N,E}
        ) where {N<:AbstractNode,E<:AbstractEdge}
    ns = []
    es = []
    adj = [Dict() for n in graph.nodes]
    nodemap = Dict()
    edgemap = Dict()
    # The order of node indices should be kept for some cannonicalization
    # operations (ex. chirality flag).
    nkeys = sort(collect(keys(graph.nodes)))
    ekeys = sort(collect(keys(graph.edges)))
    for (i, k) in enumerate(nkeys)
        nodemap[k] = i
        push!(ns, graph.nodes[k])
    end
    for (i, k) in enumerate(ekeys)
        edgemap[k] = i
        e = graph.edges[k]
        push!(es, connect(e, nodemap[e.u], nodemap[e.v]))
    end
    for (u, nbrs) in graph.adjacency
        for (v, e) in nbrs
            adj[nodemap[u]][nodemap[v]] = edgemap[e]
        end
    end
    GVectorUGraph{N,E}(ns, es, adj)
end


getnode(graph::UGraph, idx) = graph.nodes[idx]

getedge(graph::UGraph, idx) = graph.edges[idx]
getedge(graph::UGraph, u, v) = getedge(graph, graph.adjacency[u][v])

nodesiter(graph::VectorUGraph) = enumerate(graph.nodes)
nodesiter(graph::MapUGraph) = graph.nodes

nodekeys(graph::VectorUGraph) = Set(1:nodecount(graph))
nodekeys(graph::MapUGraph) = Set(keys(graph.nodes))

edgesiter(graph::VectorUGraph) = enumerate(graph.edges)
edgesiter(graph::MapUGraph) = graph.edges

edgekeys(graph::VectorUGraph) = Set(1:edgecount(graph))
edgekeys(graph::MapUGraph) = Set(keys(graph.edges))

neighbors(graph::UGraph, idx) = graph.adjacency[idx]

nodecount(graph::UGraph) = length(graph.nodes)

edgecount(graph::UGraph) = length(graph.edges)


function updatenode!(graph::MapUGraph, node, idx)
    """Add or update a node"""
    graph.nodes[idx] = node
    if !(idx in keys(graph.adjacency))
        graph.adjacency[idx] = Dict()
    end
    return
end


function updateedge!(graph::MapUGraph, edge, idx)
    """Add or update an edge"""
    if !(edge.u in keys(graph.nodes))
        throw(OperationError("Missing node: $(edge.u)"))
    elseif !(edge.v in keys(graph.nodes))
        throw(OperationError("Missing node: $(edge.v)"))
    end
    graph.edges[idx] = edge
    graph.adjacency[edge.u][edge.v] = idx
    graph.adjacency[edge.v][edge.u] = idx
    return
end

updateedge!(G, edge, u, v) = updateedge!(G, edge, graph.adjacency[u][v])


function unlinknode!(graph::MapUGraph, idx)
    """Remove a node and its connecting edges"""
    if !(idx in keys(graph.nodes))
        throw(OperationError("Missing node: $(idx)"))
    end
    for (n, nbr) in graph.adjacency[idx]
        delete!(graph.edges, nbr)
        delete!(graph.adjacency[n], idx)
    end
    delete!(graph.nodes, idx)
    delete!(graph.adjacency, idx)
    return
end


function unlinkedge!(graph::MapUGraph, u, v)
    """Remove an edge"""
    if !(u in keys(graph.nodes))
        throw(OperationError("Missing node: $(u)"))
    elseif !(v in keys(graph.nodes))
        throw(OperationError("Missing node: $(v)"))
    end
    delete!(graph.edges, graph.adjacency[u][v])
    delete!(graph.adjacency[u], v)
    delete!(graph.adjacency[v], u)
    return
end

function unlinkedge!(graph::MapUGraph, idx)
    """Remove an edge"""
    if !(idx in keys(graph.edges))
        throw(OperationError("Missing edge: $(idx)"))
    end
    e = getedge(graph, idx)
    delete!(graph.edges, idx)
    delete!(graph.adjacency[e.u], e.v)
    delete!(graph.adjacency[e.v], e.u)
    return
end


function similarmap(graph::MapUGraph)
    N = valtype(graph.nodes)
    E = valtype(graph.edges)
    GMapUGraph{N,E}()
end

function similarmap(graph::VectorUGraph)
    N = eltype(graph.nodes)
    E = eltype(graph.edges)
    GMapUGraph{N,E}()
end