package om.rtc.mesh.signal;


//@:enum abstract MessageType(Int) from Int to Int {
@:enum abstract MessageType(String) {
    //var list = 0;
    var join = "join";
    var leave = "leave";
    var offer = "offer";
    var candidate = "candidate";
    var answer = "answer";
    var error = "error";
}

typedef Message = {

    @:optional var pool : String;
    @:optional var peer : String;

    var type : MessageType;
    @:optional var data : Dynamic;
}
