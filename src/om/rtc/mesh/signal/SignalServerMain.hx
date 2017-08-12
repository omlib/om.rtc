package om.rtc;

class SignalServerMain {

    static function main() {
        var args = Sys.args();
        var server = new SignalServer( args[0], Std.parseInt( args[1] ) );
        server.start();
    }
}
