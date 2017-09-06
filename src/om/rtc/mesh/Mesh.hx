package om.rtc.mesh;

import js.html.rtc.DataChannelInit;
import js.html.rtc.IceCandidate;
import js.html.rtc.SessionDescription;
import om.rtc.mesh.Node;
import js.Browser.console;

class Mesh {

    public dynamic function onSignal( msg : Message ) {}
    public dynamic function onJoin() {}

    public dynamic function onNodeConnect( node : Node ) {}
    public dynamic function onNodeDisconnect( node : Node ) {}
    public dynamic function onNodeMessage( node : Node, msg : Message ) {}

    public var id(default,null) : String;
    public var joined(default,null) = false;
    public var joinRequestSent(default,null) = false;

    var nodes : Map<String,Node>;
    var numNodes : Int;

    public function new( id : String ) {
        this.id = id;
        nodes = new Map();
        numNodes = 0;
    }

    public inline function iterator() : Iterator<Node>
        return nodes.iterator();

    public function handleSignal( msg : Message ) {

        trace( msg );
        switch msg.type {

        case 'join':
            var data : { nodes: Array<String> } = msg.data;
            var nodeIds : Array<String> = data.nodes;
            if( nodeIds.length == 0 ) {
                //TODO
                joinRequestSent = true;
                onJoin();
            } else {
                for( id in nodeIds ) {
                    var node = createNode( id );
                    node.connectTo( createDataChannelConfig() ).then( function(sdp){
                        onSignal( { type: 'offer', data: { node: node.id, sdp: sdp } } );
                    }).catchError( function(e){
                        trace(e);
                    });
                }
            }

        case 'offer':
            var data : { node: String, sdp: Dynamic } = msg.data;
            var node = createNode( data.node );
            node.connectFrom( new SessionDescription( data.sdp ) ).then( function(sdp){
                onSignal( { type: 'answer', data: { node: node.id, sdp: sdp } } );
            }).catchError( function(e){
                trace('ERROR '+e);
            });

        case 'answer':
            var data : { node: String, sdp: Dynamic } = msg.data;
            if( !nodes.exists( data.node ) ) {
                //return;
            }
            var node = nodes.get( data.node );
            node.setRemoteDescription( new SessionDescription( data.sdp ) ).then( function(_){
                //trace('oi');
                //peer.send({type:"fucvk"});
            });

        case 'candidate':
            var data : { node: String, candidate: Dynamic } = msg.data;
            var node = nodes.get( data.node );
            node.addIceCandidate( new IceCandidate( data.candidate ) ).then( function(_){
            });
        }
    }

    public function join() {
        onSignal( { type: 'join', data: { mesh: id } } );
    }

    public function leave() {
        for( node in nodes ) node.disconnect();
        nodes = new Map();
    }

    public function broadcast( msg : Message )  {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            console.error(e);
            return;
        }
        for( node in nodes ) node.send( str );
    }

    public function getConnectedNodes() : Array<Node> {
        var nodes = new Array<Node>();
        for( n in this.nodes ) if( n.connected ) nodes.push( n );
        return nodes;
    }

    function createNode( id : String ) : Node {

        var node = new Node( id );
        nodes.set( node.id, node );
        numNodes++;

        node.onCandidate = candidate -> {
            onSignal( { type: 'candidate', data: { node: node.id, candidate: candidate } } );
        }
        node.onConnect = () -> {
            if( !joinRequestSent ) {
                node.sendMessage( { type: 'join', data: null } );
                joinRequestSent = true;
                onJoin();
            }
            onNodeConnect( node );
        }
        node.onMessage = msg -> onNodeMessage( node, msg );
        node.onDisconnect = () -> {
            nodes.remove( node.id );
            numNodes--;
            onNodeDisconnect( node );
        }

        return node;
    }

    function createDataChannelConfig() : DataChannelInit {
        return {
            ordered: true,
            outOfOrderAllowed: false,
            //maxRetransmitTime: 400,
            //maxPacketLifeTime: 1000
        };
    }
}
