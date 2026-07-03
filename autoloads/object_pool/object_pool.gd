## ObjectPool Autoload
extends BaseObjectPool
## An efficient object pooling system for managing and reusing Nodes.
##
## This autoload prevents performance spikes by reusing existing nodes instead 
## of frequently instantiating and freeing them. It manages "dormant" nodes 
## by disabling their processing and hiding them within a dedicated container.
## This extends the [BaseObjectPool] class, add any game-specific logic here
