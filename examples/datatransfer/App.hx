
import js.Browser.console;
import js.Browser.document;
import js.Browser.window;
import js.html.ButtonElement;
import js.html.DivElement;
import js.html.InputElement;
import js.html.ProgressElement;
import js.html.rtc.PeerConnection;
import haxe.Timer;

/**
	https://webrtc.github.io/samples/src/content/datachannel/datatransfer/

	This page generates and sends the specified amount of data via WebRTC datachannels.
	To accomplish this in an interoperable way, the data is split into chunks which are then transferred via the datachannel.
	The datachannel is reliable and ordered by default which is well-suited to filetransfers.
*/
class App {

	static var localConnection : Dynamic;
	static var remoteConnection : Dynamic;
	static var sendChannel : Dynamic;
	static var receiveChannel : Dynamic;
	static var pcConstraint : Dynamic;

	static var megsToSend : InputElement;
	static var sendButton : ButtonElement;
	static var orderedCheckbox : InputElement;
	static var sendProgress : ProgressElement;
	static var receiveProgress : ProgressElement;
	static var errorMessage : DivElement;

	static var receivedSize = 0;
	static var bytesToSend = 0;

	static function createConnection() {

		sendButton.disabled = true;
		megsToSend.disabled = true;

		var servers = null;
		pcConstraint = null;

		bytesToSend = Math.round( Std.parseInt( megsToSend.value ) ) * 1024 * 1024;

		// Add localConnection to global scope to make it visible from the browser console.
		//untyped window.localConnection = localConnection = new PeerConnection( servers, pcConstraint );
		//untyped window.localConnection = localConnection = new PeerConnection( servers, pcConstraint );
		//untyped window.localConnection =
		//localConnection = untyped __js__('new webkitRTCPeerConnection( '+servers+', '+pcConstraint+')' );
		localConnection = untyped __js__('new webkitRTCPeerConnection( null, null )' );

		trace('Created local peer connection object localConnection');

		var dataChannelParams = { ordered: false };
		if( orderedCheckbox.checked ) {
			dataChannelParams.ordered = true;
		}

		sendChannel = localConnection.createDataChannel( 'sendDataChannel', dataChannelParams );
		sendChannel.binaryType = 'arraybuffer';

		trace( 'Created send data channel' );

		sendChannel.onopen = onSendChannelStateChange;
		sendChannel.onclose = onSendChannelStateChange;
		localConnection.onicecandidate = iceCallback1;

		localConnection.createOffer().then( gotDescription1, onCreateSessionDescriptionError );

		//untyped window.remoteConnection = remoteConnection = untyped __js__('new webkitRTCPeerConnection( '+servers+', '+pcConstraint+')' );
		untyped window.remoteConnection = remoteConnection = untyped __js__('new webkitRTCPeerConnection( null, null )' );

		trace('Created remote peer connection object remoteConnection');

		remoteConnection.onicecandidate = iceCallback2;
		remoteConnection.ondatachannel = receiveChannelCallback;
	}

	static function onCreateSessionDescriptionError( error ) {
		trace( 'Failed to create session description: ' + error.toString() );
	}

	static function randomAsciiString( length : Int ) : String {
		var result = '';
		for( i in 0...length )
			result += String.fromCharCode( 33 + Std.int( Math.random() * 93 ) );
		return result;
	}

	static function sendGeneratedData( chunkSize = 16384 ) {

		sendProgress.max = bytesToSend;
		receiveProgress.max = sendProgress.max;
		sendProgress.value = 0;
		receiveProgress.value = 0;

		var stringToSendRepeatedly = randomAsciiString( chunkSize );
		var bufferFullThreshold = 5 * chunkSize;
		var usePolling = true;

		trace( sendChannel );
		trace( sendChannel.bufferedAmountLowThreshold );

		if( untyped __typeof__( sendChannel.bufferedAmountLowThreshold ) == 'number' ) {

			trace('Using the bufferedamountlow event for flow control');
    		usePolling = false;

			// Reduce the buffer fullness threshold, since we now have more efficient buffer management.
			bufferFullThreshold = Std.int( chunkSize / 2 );

			// This is "overcontrol": our high and low thresholds are the same.
			sendChannel.bufferedAmountLowThreshold = bufferFullThreshold;
		}

		var sendAllData : Void->Void;
		var listener : Void->Void;

		sendAllData = function() {
			while( sendProgress.value < sendProgress.max ) {
				if( sendChannel.bufferedAmount > bufferFullThreshold ) {
	        		if( usePolling ) {
						Timer.delay( sendAllData, 250 );
					} else {
						sendChannel.addEventListener( 'bufferedamountlow', listener );
					}
	    			return;
				}
				sendProgress.value += chunkSize;
				sendChannel.send( stringToSendRepeatedly );
			}
		}

		// Listen for one bufferedamountlow event.
		listener = function() {
	    	sendChannel.removeEventListener( 'bufferedamountlow', listener );
	    	sendAllData();
		};

		Timer.delay( sendAllData, 0 );
	}

	static function closeDataChannels() {

		trace('Closing data channels');
		sendChannel.close();

		trace('Closed data channel with label: ' + sendChannel.label );
		receiveChannel.close();

		trace('Closed data channel with label: ' + receiveChannel.label );
		localConnection.close();
		remoteConnection.close();

		localConnection = null;
		remoteConnection = null;

		trace('Closed peer connections');
	}

	static function gotDescription1( desc ) {

		localConnection.setLocalDescription( desc );

		trace( 'Offer from localConnection \n' + desc.sdp );

		remoteConnection.setRemoteDescription(desc);
		remoteConnection.createAnswer().then( gotDescription2, onCreateSessionDescriptionError );
	}

	static function gotDescription2( desc ) {
		remoteConnection.setLocalDescription( desc );
		trace( 'Answer from remoteConnection \n' + desc.sdp );
		localConnection.setRemoteDescription( desc );
	}

	static function iceCallback1(event) {
		trace('local ice callback');
		if( event.candidate != null ) {
			remoteConnection.addIceCandidate( event.candidate ).then( onAddIceCandidateSuccess, onAddIceCandidateError );
			trace('Local ICE candidate: \n' + event.candidate.candidate);
		}
	}

	static function iceCallback2(event) {
		trace('remote ice callback');
		if( event.candidate != null ) {
			localConnection.addIceCandidate( event.candidate ).then( onAddIceCandidateSuccess, onAddIceCandidateError );
    		trace('Remote ICE candidate: \n ' + event.candidate.candidate);
		}
	}

	static function onAddIceCandidateSuccess() {
		trace('AddIceCandidate success.');
	}

	static function onAddIceCandidateError(error) {
		trace( 'Failed to add Ice Candidate: ' + error.toString() );
	}

	static function receiveChannelCallback(event) {
		trace('Receive Channel Callback');
		receiveChannel = event.channel;
		receiveChannel.binaryType = 'arraybuffer';
		receiveChannel.onmessage = onReceiveMessageCallback;
		receivedSize = 0;
	}

	static function onReceiveMessageCallback(event) {

		receivedSize += event.data.length;
		receiveProgress.value = receivedSize;

		if( receivedSize == bytesToSend ) {
			closeDataChannels();
			sendButton.disabled = false;
			megsToSend.disabled = false;
		}
	}

	static function onSendChannelStateChange() {
		var readyState = sendChannel.readyState;
		trace('Send channel state is: ' + readyState);
		if( readyState == 'open' ) {
			sendGeneratedData();
		}
	}

	static function main() {

		window.onload = function(){

			megsToSend = cast document.querySelector( 'input#megsToSend' );
			sendButton = cast document.querySelector( 'button#sendTheData' );
			orderedCheckbox = cast document.querySelector( 'input#ordered' );
			sendProgress = cast document.querySelector( 'progress#sendProgress' );
			receiveProgress = cast document.querySelector( 'progress#receiveProgress' );
			errorMessage = cast document.querySelector( 'div#errorMsg' );

			sendButton.onclick = createConnection;
		}
	}
}
