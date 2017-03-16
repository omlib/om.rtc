
import js.Browser.console;
import js.Browser.document;
import js.Browser.window;
import js.html.rtc.PeerConnection;
import js.html.rtc.SessionDescription;
import haxe.Timer;

/*
	https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Simple_RTCDataChannel_sample
*/
class App {

	static function main() {

		var lc = new PeerConnection();
		var rc = new PeerConnection();

		lc.onicecandidate = function(e){
			if( e.candidate != null ) rc.addIceCandidate( e.candidate );
		}

		var sendChannel = lc.createDataChannel( "channel-1" );
		sendChannel.onopen = function(e) {
			sendChannel.send( 'ping' );
		}
		sendChannel.onmessage = function(e) {
			trace(e);
			Timer.delay( function() sendChannel.send( 'ping' ), 1000 );
		}
		sendChannel.onclose = function(e) trace(e);

		rc.ondatachannel = function(e) {
			var receiveChannel = e.channel;
			receiveChannel.onmessage = function(e) {
				trace(e);
				Timer.delay( function() receiveChannel.send( 'pong' ), 1000 );
			}
			receiveChannel.onopen = function(e) trace(e);
			receiveChannel.onclose = function(e) trace(e);
		}
		rc.onicecandidate = function(e){
			if( e.candidate != null ) lc.addIceCandidate( e.candidate );
		}

		lc.createOffer()
			.then( function(desc) lc.setLocalDescription( desc ) )
			.then( function(_) rc.setRemoteDescription( lc.localDescription ) )
			.then( function(_) rc.createAnswer()
			.then( function(answer) rc.setLocalDescription( answer ) )
			.then( function(_) lc.setRemoteDescription( rc.localDescription ) ) )
			.catchError( function(e){
				trace(e);
			}
		);
	}
}
