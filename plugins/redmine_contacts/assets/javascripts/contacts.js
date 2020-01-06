// Copyright (c) 2011-2013 Kirill Bezrukov

var noteFileFieldCount = 1;

function addNoteFileField() {
	if (noteFileFieldCount >= 10) return false
	noteFileFieldCount++;
	var f = document.createElement("input");
	f.type = "file";
	f.name = "note_attachments[" + noteFileFieldCount + "][file]";
	f.size = 30;
	var d = document.createElement("input");
	d.type = "text";
	d.name = "note_attachments[" + noteFileFieldCount + "][description]";
	d.size = 60;

	p = document.getElementById("note_attachments_fields");
	p.appendChild(document.createElement("br"));
	p.appendChild(f);
	p.appendChild(d);
}

function updateCustomForm(url, form) {
  $.ajax({
    url: url,
    type: 'post',
    data: $(form).serialize()
  });
}

function toggleContact(event, element)
{
	if (event.shiftKey==1)
	{
		if (element.checked) {
			checkAllContacts($$('.contacts.index td.checkbox input'));
		}
		else
		{
			uncheckAllContacts($$('.contacts.index td.checkbox input'));
		}
	}
	else
	{
		Element.up(element, 'tr').toggleClassName('context-menu-selection');
	}
}


// Observ field function

(function( $ ){

  jQuery.fn.observe_field = function(frequency, callback) {

    frequency = frequency * 100; // translate to milliseconds

    return this.each(function(){
      var $this = $(this);
      var prev = $this.val();

      var check = function() {
        if(removed()){ // if removed clear the interval and don't fire the callback
          if(ti) clearInterval(ti);
          return;
        }

        var val = $this.val();
        if(prev != val){
          prev = val;
          $this.map(callback); // invokes the callback on $this
        }
      };

      var removed = function() {
        return $this.closest('html').length == 0
      };

      var reset = function() {
        if(ti){
          clearInterval(ti);
          ti = setInterval(check, frequency);
        }
      };

      check();
      var ti = setInterval(check, frequency); // invoke check periodically

      // reset counter after user interaction
      $this.bind('keyup click mousemove', reset); //mousemove is for selects
    });

  };

  $.fn.insertAtCaret = function (myValue) {

    return this.each(function() {

      //IE support
      if (document.selection) {

        this.focus();
        sel = document.selection.createRange();
        sel.text = myValue;
        this.focus();

      } else if (this.selectionStart || this.selectionStart == '0') {

        //MOZILLA / NETSCAPE support
        var startPos = this.selectionStart;
        var endPos = this.selectionEnd;
        var scrollTop = this.scrollTop;
        this.value = this.value.substring(0, startPos)+ myValue+ this.value.substring(endPos,this.value.length);
        this.focus();
        this.selectionStart = startPos + myValue.length;
        this.selectionEnd = startPos + myValue.length;
        this.scrollTop = scrollTop;

      } else {

        this.value += myValue;
        this.focus();
      }
    });
  };


})( jQuery );

function setupDeferredTabs(url) {
    $('body').on('click', '.tab-header', function(e){
        tab = $(e.target);
        $('.tab-placeholder').removeClass('active');
        name = tab.data('name');
        partial = tab.data('partial');
        placeholder = $('#tab-placeholder-' + name);
        placeholder.addClass('active');

        if (!placeholder.is('.loaded')) {
            url = url
            $.ajax(url, {
                data: {tab_name: name, partial: partial},
                complete: function(){
                    placeholder.addClass('loaded')
                    //replaces current URL with the "href" attribute of the current link
                    //(only triggered if supported by browser)
                    if ("replaceState" in window.history) {
                      window.history.replaceState(null, document.title, tab.attr('href'));
                    }
                    return undefined;
                },
                dataType: 'script'
            })
        }
        else {
            if ("replaceState" in window.history) {
                window.history.replaceState(null, document.title, tab.attr('href'));
            }
        }
    })
};

function selectAllOptions(id) {
  var select = $('#'+id);
  select.children('option').attr('selected', true);
}


function submit_query_form(id) {
  selectAllOptions("selected_columns");
  $('#'+id).submit();
}

//replaces redmine default method showTab() beacuse of compatibility Redmine 3.1+
function showContactTab(name, url) {
  $('div#content .tab-content').hide();
  $('div.tabs a').removeClass('selected');
  $('#tab-content-' + name).show();
  $('#tab-' + name).addClass('selected');
  if ("replaceState" in window.history) {
    window.history.replaceState(null, document.title, url);
  }
  return false;
}

function tooglePriceField() {
  $('#deal_price').prop( "disabled", $('.line:visible').size() > 0 );
}

function toggleCRMIssuesSelection(el) {
  var boxes = $(el).parents('form').find('input[type=checkbox]');
  var all_checked = true;
  boxes.each(function(){ if (!$(this).prop('checked')) { all_checked = false; } });
  boxes.each(function(){
    if (all_checked) {
      $(this).removeAttr('checked');
      $(this).parents('tr').removeClass('context-menu-selection');
    } else if (!$(this).prop('checked')) {
      $(this).prop('checked', true);
      $(this).parents('tr').addClass('context-menu-selection');
    }
  });
}

function toogleDealItems(el) {
  $(el).closest('p').hide();
  $('.deal_items').show();
}

function uploadAvatar(element) {
  var fileSpan = $('<span>', { id: 'attachments_0'});
  $('#contact_data #attachments_fields').html('');
  fileSpan.append(
      $('<input>', { type: 'hidden', class: 'filename', name: 'attachments[0][filename]'} ).val(element.files[0].name),
      $('<input>', { type: 'hidden', class: 'description', name: 'attachments[0][description]' } ).val('avatar'),
      $('<input>', { type: 'hidden', class: 'token', name: 'attachments[0][token]' } )
  ).appendTo('#contact_data #attachments_fields');
  ajaxUpload(element.files[0], 0, fileSpan, element);
  return 0;
}
