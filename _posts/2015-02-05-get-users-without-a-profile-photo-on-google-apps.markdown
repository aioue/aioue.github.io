---
layout: post
title: Get users without a profile photo on Google Apps
date: '2015-02-05 21:43:19'
---

To find users without a profile photo or avatar, run this in the [Google Apps Script editor](http://script.google.com):  
  
```  
/**  
 * Get all the users without a profile photo set  
 */  
function getUsersWithNoProfilePhoto() {  
  
  // get users domain (e.g. company.com)  
  var email = Session.getActiveUser().getEmail();  
  user_domain = email.replace(/.*@/, "");  
  
  var console_text = ""  
  
  var pageToken, page;  
  do {  
    page = AdminDirectory.Users.list({  
      domain: user_domain,  
      orderBy: 'givenName',  
      maxResults: 100,  
      pageToken: pageToken  
    });  
    var users = page.users;  
    if (users) {  
      for (var i = 0; i < users.length; i++) {  
        var user = users[i];  
  
        if (!user.thumbnailPhotoUrl) {  
          // Logger.log('Photo not set for %s', user.primaryEmail);  
          console_text = console_text + user.primaryEmail + "\n";  
        }  
      }  
    } else {  
      Logger.log('No users found.');  
    }  
    pageToken = page.nextPageToken;  
  } while (pageToken);  
  //Logger.log(console_text);  
  return console_text;  
}  
  
function doGet() {  
    return ContentService.createTextOutput(getUsersWithNoProfilePhoto());  
}  
```
  
[Compiled version (requires permissions)](https://script.google.com/macros/s/AKfycbyU6Io0dp7MkRSqVinQR5I1P5RWmMJwxt2iokU_X-GvPYKQgIU/exec)