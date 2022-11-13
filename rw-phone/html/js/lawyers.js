SetupLawyers = function(data) {
    $(".lawyers-list").html("");

    if (data.length > 0) {
        $.each(data, function(i, lawyer){
            var element = '<div class="lawyer-list" id="lawyerid-'+i+'"> <div class="lawyer-list-firstletter">' + lawyer.firstname + '</div> <div class="lawyer-list-fullname">' + lawyer.firstname + " " + lawyer.lastname + '</div> <div class="lawyer-list-call"><i class="fas fa-phone"></i></div> </div>'
            $(".lawyers-list").append(element);
            $("#lawyerid-"+i).data('LawyerData', lawyer);
        });
    } else {
        var element = '<div class="lawyer-list"><div class="no-lawyers">There are no lawyers available.</div></div>'
        $(".lawyers-list").append(element);
    }
}

$(document).on('click', '.lawyer-list-call', function(e){
    e.preventDefault();

    var LawyerData = $(this).parent().data('LawyerData');
    
    var cData = {
        number: LawyerData.phone,
        name: LawyerData.name
    }

    $.post('http://rw-phone/CallContact', JSON.stringify({
        ContactData: cData,
        Anonymous: RL.Phone.Data.AnonymousCall,
    }), function(status){
        if (cData.number !== RL.Phone.Data.PlayerData.charinfo.phone) {
            if (status.IsOnline) {
                if (status.CanCall) {
                    if (!status.InCall) {
                        if (RL.Phone.Data.AnonymousCall) {
                            RL.Phone.Notifications.Add("fas fa-phone", RL.Phone.Functions.Lang("PHONE_TITLE"), RL.Phone.Functions.Lang("PHONE_STARTED_ANON"));
                        }
                        $(".phone-call-outgoing").css({"display":"block"});
                        $(".phone-call-incoming").css({"display":"none"});
                        $(".phone-call-ongoing").css({"display":"none"});
                        $(".phone-call-outgoing-caller").html(cData.name);
                        RL.Phone.Functions.HeaderTextColor("white", 400);
                        RL.Phone.Animations.TopSlideUp('.phone-application-container', 400, -160);
                        setTimeout(function(){
                            $(".lawyers-app").css({"display":"none"});
                            RL.Phone.Animations.TopSlideDown('.phone-application-container', 400, 0);
                            RL.Phone.Functions.ToggleApp("phone-call", "block");
                        }, 450);
    
                        CallData.name = cData.name;
                        CallData.number = cData.number;
                    
                        RL.Phone.Data.currentApplication = "phone-call";
                    } else {
                        RL.Phone.Notifications.Add("fas fa-phone", RL.Phone.Functions.Lang("PHONE_TITLE"), RL.Phone.Functions.Lang("PHONE_BUSY"));
                    }
                } else {
                    RL.Phone.Notifications.Add("fas fa-phone", RL.Phone.Functions.Lang("PHONE_TITLE"), RL.Phone.Functions.Lang("PHONE_PERSON_TALKING"));
                }
            } else {
                RL.Phone.Notifications.Add("fas fa-phone", RL.Phone.Functions.Lang("PHONE_TITLE"), RL.Phone.Functions.Lang("PHONE_PERSON_UNAVAILABLE"));
            }
        } else {
            RL.Phone.Notifications.Add("fas fa-phone", RL.Phone.Functions.Lang("PHONE_TITLE"), RL.Phone.Functions.Lang("PHONE_YOUR_NUMBER"));
        }
    });
});