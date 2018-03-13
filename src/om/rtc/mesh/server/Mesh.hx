package om.rtc.mesh.server;

import js.Promise;

@:require(nodejs)
class Mesh {

    public var id(default,null) : String;
    public var nodes(default,null) = new Map<String,Node>();
    public var numNodes(default,null) = 0;
    //public var maxNodes(default,null) : Int;

    public function new( id : String, maxNodes = 100 ) {
        this.id = id;
        //this.maxNodes = maxNodes;
    }

    public inline function iterator() : Iterator<Node>
        return nodes.iterator();

    public function start() : Promise<Nil>
        return Promise.resolve( null );

    public function stop() : Promise<Nil>
        return Promise.resolve( null );

    public inline function has( id : String ) : Bool
        return nodes.exists( id );

    public function add( node : Node ) : Bool {
        if( has( id ) )
            return false;
        nodes.set( node.id, node );
        node.meshes.push( id );
        numNodes++;
        return true;
    }

    public function remove( id : String ) : Bool {
        if( !has( id ) )
            return false;
        var node = nodes.get( id );
        nodes.remove( id );
        node.meshes.remove( this.id );
        numNodes--;
        return true;
    }

    public function broadcast( str : String )
        for( n in nodes ) n.sendString( str );

}
