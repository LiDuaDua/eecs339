/*jshint indent: 4, quotmark: single, strict: true */
/* global $: false, _: false, CryptoJS: false, alert: false */
window.portfolio = (function(){
	'use strict';

	//state variables
	var portfolios, currentPortfolio = 0, symbols = [],
	LS = localStorage,

	init = function(){
		//if portfolio_username and portfolio_password are set, assume valid credentials
		if(LS.portfolio_full_name && LS.portfolio_username && LS.portfolio_password){
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
					LS.portfolio_full_name = reply.FULL_NAME;
					LS.portfolio_username = data.username;
					LS.portfolio_password = data.password;
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
					LS.portfolio_full_name = data.full_name;
					LS.portfolio_username = data.username;
					LS.portfolio_password = data.password;

					$.getJSON('./ajax/addPortfolio.php',{name: 'Default', username: LS.portfolio_username}, function(reply){
						if(reply.status){
							currentPortfolio = 0;
							startSession();
						}else{
							alert(reply.message);
						}
					});
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
		$('#navbar-items').html(template({full_name: LS.portfolio_full_name}));

		$.getJSON('./ajax/getUserPortfolios.php',{username: LS.portfolio_username},function(reply){
			if(reply.length > 0){
				portfolios = reply;
				renderPortfolio(currentPortfolio);
			}
		});

		$.getJSON('./ajax/getSymbols.php',function(reply){
			symbols = reply;

			$('#symbol-input').typeahead({
				name: 'stock-symbols',
				local: symbols
			});

			$('#symbol-input').on('typeahead:closed',function(){
				var sym = $(this).val(),
					ind = symbols.indexOf(sym);

				if(ind !== -1){
					$.getJSON('./ajax/quote.php',{symbol: symbols[ind]},function(reply){
						var close = parseFloat(reply[symbols[ind]].close,10),
							shares = parseInt($('#symbol-shares').val(),10);
						$('#symbol-cost').val(close);
						$('#symbol-total').val(close*shares);
					});
				}
			});

			$('#symbol-shares').on('change',function(){
				var shares = parseInt($(this).val(),10),
					close = parseFloat($('#symbol-cost').val(),10);

				$('#symbol-total').val(shares*close);
			});
		});

		$('#logout').on('click',function(){
			LS.portfolio_full_name = '';
			LS.portfolio_username = '';
			LS.portfolio_password = '';

			newUser();
		});

		$('#new-portfolio-form').on('submit', function(){
			$.getJSON('./ajax/addPortfolio.php',{
				name: $(this).find('input:first').val(),
				username: LS.portfolio_username
			}, function(reply){
				if(reply.status){
					$('#new-portfolio').modal('hide');
					currentPortfolio = portfolios.length;
					startSession();
				}
			});

			return false;
		});

		$('#deposit-withdraw-form').on('submit', function(){
			var ammount = parseFloat($(this).find('input:first').val(),10) *
				($(this).find('.btn.active>input').attr('id') == 'deposit' ? 1 : -1);

			$.getJSON('./ajax/modifyCash.php',{portfolio_id: portfolios[currentPortfolio].PORTFOLIO_ID, ammount: ammount},function(reply){
				if(reply.status){
					$('#deposit-withdraw').modal('hide');
					portfolios[currentPortfolio].CASH_ACCOUNT = parseFloat(portfolios[currentPortfolio].CASH_ACCOUNT,10) + ammount;
					renderPortfolio(currentPortfolio);
				}else{
					//while debugging
					alert(reply.message);
				}
			});

			return false;
		});

		$('#add-transaction-form').on('submit',function(){


			return false;
		});
	},

	renderPortfolio = function(ind){
		var template = _.template($('#template-portfolio').html()),
		list = [];

		for(var i=0; i<portfolios.length; i++){
			list.push(portfolios[i].NAME);
		}

		$('#content').html(template({
			name: portfolios[ind].NAME,
			portfolios: list,
			balance: portfolios[ind].CASH_ACCOUNT
		}));

		$('#portfolio-list').on('click','.portfolio-item',function(){
			if(!$(this).hasClass('active')){
				var list = $('#portfolio-list').find('.portfolio-item');
				currentPortfolio = list.index($(this));
				list.removeClass('active');
				list.eq(currentPortfolio).addClass('active');

				renderPortfolio(currentPortfolio);
			}
		});
	},

	stockDetails = function(symbol){
		$.getJSON('./ajax/quotehist.php',{symbol: symbol}, function(data){
			$('#stock-chart').highcharts('StockChart',{
				title: {
					text: symbol + ' Stock History'
				},
				series: [{
					name: symbol,
					data: data
				}]
			});
		});
	},

	addAlert = function(text){
		$('<div />').addClass('alert alert-warning')
			.html(text + ' <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>')
			.prependTo('#content');
	};

	return {
		init: init
	};
})();