/*jshint indent: 4, quotmark: single, strict: true */
/* global $: false, _: false, CryptoJS: false */
window.portfolio = (function(){
	'use strict';

	var init = function(){
		//here's where things get lazy. If portfolio_username and portfolio_password are set, assume valid credentials
		if(localStorage.portfolio_full_name && localStorage.portfolio_username && localStorage.portfolio_password){
			startSession();
		}else{
			newUser();
		}
	},

	newUser = function(){
		$('#navbar-items').html($('#template-new-user-navbar').html());
		$('#login-form').on('submit', function(){
			var data = {};
			$(this).find('input').each(function(i, el){
				data[el.name] = el.value;
			});

			data.password = CryptoJS.MD5(data.password).toString();

			$.getJSON('./ajax/login.php', data, function(reply){
				if(reply){
					localStorage.portfolio_full_name = reply['FULL_NAME'];
					localStorage.portfolio_username = data.username;
					localStorage.portfolio_password = data.password;
					startSession();
				}else{
					addAlert('Login Failed');
				}
			});

			return false;
		});

		$('#signup-form').on('submit', function(){
			var data = {};
			$(this).find('input').each(function(i, el){
				data[el.name] = el.value;
			});

			data.password = CryptoJS.MD5(data.password).toString();

			$.getJSON('./ajax/signup.php',data,function(reply){
				if(reply.status){
					$('#signup').modal('hide');
					localStorage.portfolio_full_name = data.full_name;
					localStorage.portfolio_username = data.username;
					localStorage.portfolio_password = data.password;
				}else{
					//while debugging
					alert(reply.message);
				}
			});

			return false;
		});
	},

	startSession = function(){
		var template = _.template($('#template-user-session-navbar').html());
		$('#navbar-items').html(template({full_name: localStorage.portfolio_full_name}));

		$('#logout').on('click',function(){
			localStorage.portfolio_full_name = '';
			localStorage.portfolio_username = '';
			localStorage.portfolio_password = '';

			newUser();
		});

		$('#new-portfolio-form').on('submit', function(){
			$.getJSON('./ajax/addPortfolio.php',{name: $(this).find('input:first').val()}, function(reply){
				if(reply.status){
					$('#new-portfolio').modal('hide');
				}
			});

			return false;
		});
	},

	addAlert = function(text){
		$('<div />').addClass('alert alert-warning')
			.html(text + ' <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>')
			.prependTo('.content');
	};

	return {
		init: init
	};
})();