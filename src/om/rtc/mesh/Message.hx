package om.rtc.mesh;

@:enum abstract MessageType(String) from String to String {
    var join = "join";
    var offer = "offer";
    var answer = "answer";
    var candidate = "candidate";
}

typedef Message = {
    var type : MessageType;
    var data : Any;
}
