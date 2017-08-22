package om.rtc.mesh;

import js.html.rtc.DataChannelInit;
import js.html.rtc.SessionDescription;
import om.rtc.mesh.Node;
import js.Browser.console;

class Mesh {

    public dynamic function signal( msg : Dynamic ) {}

    public dynamic function onConnect( node : Node ) {}
    public dynamic function onDisconnect( node : Node ) {}
    public dynamic function onMessage( node : Node, msg : Dynamic ) {}

    public var id(default,null) : String;
    public var joined(default,null) = false;

    var nodes : Map<String,Node>;
    var joinRequestSent = false;

    public function new( id : String ) {
        this.id = id;
        nodes = new Map();
    }

    // signal
    public function receive( msg : Dynamic ) {

        switch msg.type {

        case 'join':
            var nodeIds : Array<Dynamic> = msg.data.nodes;
            if( nodeIds.length == 0 ) {
                //TODO
                joinRequestSent = true;
            } else {
                for( id in nodeIds ) {
                    var node = createNode( id );
                    node.connectTo( createDataChannelConfig() ).then( function(sdp){
                        signal( { type: 'offer', data: { node: node.id, sdp: sdp } } );
                    }).catchError( function(e){
                        trace(e);
                    });
                }
            }

        case 'offer':
            var node = createNode( msg.data.node );
            node.connectFrom( new SessionDescription( msg.data.sdp ) ).then( function(sdp){
                signal( { type: 'answer', data: { node: node.id, sdp: sdp } } );
            }).catchError( function(e){
                trace('ERROR '+e);
            });

        case 'answer':
            if( !nodes.exists( msg.data.node ) ) {
                //return;
            }
            var node = nodes.get( msg.data.node );
            node.setRemoteDescription( new SessionDescription( msg.data.sdp ) ).then( function(_){
                //trace('oi');
                //peer.send({type:"fucvk"});
            });

        case 'candidate':
            var node = nodes.get( msg.data.node );
            node.addIceCandidate( msg.data.candidate ).then( function(_){
            });
        }
    }

    public function broadcast( msg : Dynamic )  {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            console.error(e);
            return;
        }
        for( node in nodes ) node.send( str );
    }

    public function join() {
        signal( { type: 'join', data: { mesh: id } } );
    }

    public function leave() {
        for( node in nodes ) node.disconnect();
        nodes = new Map();
    }

    public function getConnectedNodes() : Array<Node> {
        var nodes = new Array<Node>();
        for( node in this.nodes ) if( node.connected ) nodes.push( node );
        return nodes;
    }

    function createNode( id : String ) : Node {

        var node = new Node( id );
        nodes.set( node.id, node );

        node.onCandidate = candidate -> {
            signal( { type: 'candidate', data: { node: node.id, candidate: candidate } } );
        }
        node.onConnect = () -> {
            if( !joinRequestSent ) {
                node.sendMessage( { type: 'join' } );
                joinRequestSent = true;
            }
            onConnect( node );
        }
        node.onMessage = msg -> onMessage( node, msg );
        node.onDisconnect = () -> {
            nodes.remove( node.id );
            onDisconnect( node );
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
