var public_key_2048 = '-----BEGIN PUBLIC KEY-----\n\
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy/z8qd4xz4UsyOEhQUmy\n\
6B6z50ozCKB94qeevRhh3XnK3LKEJxBpfmIOjUMrM/q7P1c4UrTG3ExnwzwiMzn0\n\
JPCSRZ9WlRRE4F1zY+axoZUmc/du533zXU/32jkUfYltngegvJqsz7DRMzkJInPk\n\
PPyZskgvVxhGu5mn+RUwXMQOTBA+0ensVfUfawJMQ1xmsRBjfIRlZPbG1hrlkNgf\n\
hvJmRH0xRXUp7aA8I2A0a0eYOM/cTkpeTrY4+KCDXAaYlyeX5j6mq/rBlax03dt3\n\
IwREnnZON696BW1iDpyElM/YfgS3RQyDmGhmeWaBRXVoeqqrc3QghqUn+3BR7tyL\n\
/wIDAQAB\n\
-----END PUBLIC KEY-----';

function certParser(cert){
  var lines = cert.split('\n');
  var read = false;
  var b64 = false;
  var end = false;
  var flag = '';
  var retObj = {};
  retObj.info = '';
  retObj.salt = '';
  retObj.iv;
  retObj.b64 = '';
  retObj.aes = false;
  retObj.mode = '';
  retObj.bits = 0;
  for(var i=0; i< lines.length; i++){
    flag = lines[i].substr(0,9);
    if(i==1 && flag != 'Proc-Type' && flag.indexOf('M') == 0)//unencrypted cert?
      b64 = true;
    switch(flag){
      case '-----BEGI':
        read = true;
        break;
      case 'Proc-Type':
        if(read)
          retObj.info = lines[i];
        break;
      case 'DEK-Info:':
        if(read){
          var tmp = lines[i].split(',');
          var dek = tmp[0].split(': ');
          var aes = dek[1].split('-');
          retObj.aes = (aes[0] == 'AES')?true:false;
          retObj.mode = aes[2];
          retObj.bits = parseInt(aes[1]);
          retObj.salt = tmp[1].substr(0,16);
          retObj.iv = tmp[1];
        }
        break;
      case '':
        if(read)
          b64 = true;
        break;
      case '-----END ':
        if(read){
          b64 = false;
          read = false;
        }
      break;
      default:
        if(read && b64)
          retObj.b64 += pidCryptUtil.stripLineFeeds(lines[i]);
    }
  }
  return retObj;
}

function pausecomp(millis)
 {
  var date = new Date();
  var curDate = null;
  do { curDate = new Date(); }
  while(curDate-date < millis);
}

function parseVotesFromList(ul_name) {
    votes = "";
    $(ul_name).each(function(index) {
        $(this).find('li').each(function(){
            if ($(this).hasClass("selected")) {
                //alert($(this).attr('id') + ': ' + $(this).text());
                votes += $(this).attr('id').split("_")[1];
                votes += ",";
            }
        });
    });
    return votes;
}

function packVote() {
    var encryptedVote;
    // Read vote selection directly from the UL list, to ensure that they are sent to the server the same way as the user sees them
    construction_votes = parseVotesFromList('#options_construction');
    maintenance_votes = parseVotesFromList('#options_maintenance');

    var vote = "["+"["+construction_votes+"]"+","+"["+maintenance_votes+"]"+"]";
    //alert(vote);

    var params = certParser(public_key_2048);
    //alert(params);
    if(params.b64) {
        var key = pidCryptUtil.decodeBase64(params.b64);
        //new RSA instance
        var rsa = new pidCrypt.RSA();
        //RSA encryption
        //ASN1 parsing
        //alert(key);
        //alert(rsa);
        var asn = pidCrypt.ASN1.decode(pidCryptUtil.toByteArray(key));
        //alert(asn);
        var tree = asn.toHexTree();
        //alert("tree");
        //setting the public key for encryption
        rsa.setPublicKeyFromASN(tree);
        //alert("rsa set");
        //alert(vote);
        crypted = rsa.encrypt(vote);
        //alert("encrypt");
        encryptedVote = pidCryptUtil.fragment(pidCryptUtil.encodeBase64(pidCryptUtil.convertFromHex(crypted)),64);
        //alert(encryptedVote);
        return encryptedVote;
     } else {
        alert('Could not find public key.');
        return "";
    }
};
$(function() {
    // Disable vote button until something has been selected
    $(".button").attr("disabled", true);
    $("#submit_btn").attr({src: "/assets/vote_"+locale+"_grey.png"});

    // Behavior of the submit button
    $(".button").click(function() {
        $(".button").attr("disabled", true);
        $("#submit_btn").attr({src: "/assets/vote_"+locale+"_grey.png"});
        var dataString = packVote();
        $.ajax({
          type: "POST",
          url: "/votes/post_vote",
          data: { vote : dataString, neighborhood_id : $('input:hidden').val() },
          dataType: "json",
          success: function(response) {
            if (response[0] && response[0].vote_ok==true) {
              $('#content').html("<div id='success_message'> </div><div id='message'></div>");
              $('#vote_count').html(response[0].vote_count);
              $('#message').html(response[0].message)
            } else if (response[0] && response[0].message) {
              $('#content').html("<div id='success_message'> </div><div id='message'></div>");
              $('#message').html(response[0].message)
            }
          }
         });
        return false;
    });
});