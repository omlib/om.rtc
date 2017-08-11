package om.rtc.mesh;

import haxe.crypto.Base64;

class Util {

    public static function createRandomString( length : Int ) : String {
		var CHARS = Base64.CHARS.substr( 0, Base64.CHARS.length-2 );
		var buf = new Array<String>();
		for( i in 0...length )
			buf.push( CHARS.charAt( Std.int( Math.random() * CHARS.length-1 ) ) );
		return buf.join( '' );
	}
}
