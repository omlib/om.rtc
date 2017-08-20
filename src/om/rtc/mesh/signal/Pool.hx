package om.rtc.mesh.signal;

import om.rtc.mesh.signal.Message;

class Pool {

    public var id(default,null) : String;
    //public var permanent(default,null) : Bool;
    //public var password(default,null) : String;

    var peers : Map<String,Peer>;
    var numPeers : Int;

    public function new( id : String, permanent = false ) {
        this.id = id;
        //this.permanent = permanent;
        //this.password = password;
        peers = new Map();
        numPeers = 0;
    }

    public inline function iterator()
        return peers.iterator();

    public function start() {}

    public function stop() {}

    public inline function has( peer : Peer ) : Bool
        return peers.exists( peer.id );

    public inline function get( id : String ) : Peer
        return peers.get( id );

    public function add( peer : Peer ) : Bool {
        if( has( peer ) )
            return false;
        peers.set( peer.id, peer );
        peer.pools.set( this.id, this );
        numPeers++;
        peer.sendMessage( {
            type: join,
            pool: id,
            data: {
                id: peer.id,
                peers: [for(p in peers) if(p.id != peer.id) p.id]
            }
        });
        return true;
    }

    public function remove( peer : Peer ) : Bool {
        if( !has( peer ) )
            return false;
        peers.remove( peer.id );
        peer.pools.remove( this.id );
        numPeers--;
        return true;
    }

    public function removeAll() {
        for( peer in peers ) {
            peers.remove( peer.id );
            peer.pools.remove( this.id );
        }
        numPeers = 0;
    }

    public function receive( peer : Peer, data : Dynamic ) {
        //TODO handle core signal messages here ?
    }

    public function broadcast( str : String ) {
        for( peer in peers ) {
            peer.sendString( str );
        }
    }

    //public function update() {

    public function destroy() {
        //TODO
    }
}
