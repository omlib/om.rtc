package om.rtc.mesh.signal;

import om.rtc.mesh.signal.Message;

class Pool {

    public var id(default,null) : String;

    var map : Map<String,Peer>;

    public function new( id : String ) {
        this.id = id;
        map = new Map();
    }

    public inline function iterator()
        return map.iterator();

    public inline function get( id : String ) : Peer
        return map.get( id );

    public function add( peer : Peer ) : Bool {

        if( map.exists( peer.id ) )
            return false;

        peer.sendMessage( {
            type: join,
            pool: id,
            data: {
                id: peer.id,
                //peers: [for(p in map) if(p.id != peer.id) p.id]
                peers: [for( p in map ) p.id]
            }
        });

        map.set( peer.id, peer );
        peer.pools.set( this.id, this );

        return true;
    }

    public function remove( peer : Peer ) : Bool {

        if( !map.exists( peer.id ) )
            return false;

        map.remove( peer.id );
        peer.pools.remove( this.id );

        return true;
    }

    public function update() {
    }

    public function destroy() {
        //TODO
    }
}
