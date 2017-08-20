package om.rtc.mesh.signal;

//@:enum abstract MessageType(Int) from Int to Int {
@:enum abstract MessageType(String) {

    //var list = "list";

    var error = "error";

    var join = "join";
    var leave = "leave";

    var offer = "offer";
    var candidate = "candidate";
    var answer = "answer";

    var ping = "ping";
    var pong = "pong";

    //var data = "data";

    //#if om_rtc_monitor
    //var monitor = "monitor";
    //#end
}

typedef Message = {

    var type : MessageType;
    @:optional var data : Dynamic;

    @:optional var pool : String;
    @:optional var peer : String;
}
