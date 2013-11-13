/*jshint indent: 4, quotmark: single, strict: true */
/* global $: false, _: false, CryptoJS: false, NProgress: false */
window.portfolio = (function(){
	'use strict';

	//state variables
	var portfolios, currentPortfolio = 0, symbols = [],
	LS = localStorage,

	init = function(){
		if(LS.portfolio_full_name && LS.portfolio_username && LS.portfolio_password){
			login({
				full_name: LS.portfolio_full_name,
				username: LS.portfolio_username,
				password: LS.portfolio_password
			});
		}else{
			newUser();
		}

		NProgress.configure({
			trickleRate: 0.1
		});
		$(document).on('ajaxStart', NProgress.start);
		$(document).on('ajaxStop', NProgress.done);
	},

	newUser = function(){
		$('#navbar-items').html($('#template-new-user-navbar').html());
		$('#login-form').on('submit', function(){
			var data = {};
			$(this).find('input').each(function(i, el){
				data[el.name] = el.value;
			});

			data.password = CryptoJS.MD5(data.password).toString();

			login(data);

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
					$('#signup-form').find('.alert-info').hide();
					LS.portfolio_full_name = data.full_name;
					LS.portfolio_username = data.username;
					LS.portfolio_password = data.password;

					$.getJSON('./ajax/addPortfolio.php',{name: 'Default', username: LS.portfolio_username}, function(reply){
						if(reply.status){
							currentPortfolio = 0;
							startSession();
						}else{
							addAlert(reply.message);
						}
					});
				}else{
					$('#signup-form').find('.alert-info').text(reply.message).show();
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

		if(symbols.length === 0){ loadSymbols(); }

		$('#logout').on('click',logout);

		$('#new-portfolio-form').on('submit', function(){
			$.getJSON('./ajax/addPortfolio.php',{
				name: $(this).find('input:first').val(),
				username: LS.portfolio_username
			}, function(reply){
				$('#new-portfolio').modal('hide');
				if(reply.status){
					currentPortfolio = portfolios.length;
					startSession();
				}else{
					addAlert(reply.message);
				}
			});

			return false;
		});

		$('#deposit-withdraw-form').on('submit', function(){
			var ammount = parseFloat($(this).find('input:first').val(),10) *
				($(this).find('.btn.active>input').attr('id') == 'deposit' ? 1 : -1);

			$.getJSON('./ajax/modifyCash.php',{portfolio_id: portfolios[currentPortfolio].ID, ammount: ammount},function(reply){
				if(reply.status){
					$('#deposit-withdraw').modal('hide');
					$('#deposit-withdraw').find('.alert-info').hide();
					portfolios[currentPortfolio].CASH_ACCOUNT = parseFloat(portfolios[currentPortfolio].CASH_ACCOUNT,10) + ammount;
					$('#cash-account').text('$'+portfolios[currentPortfolio].CASH_ACCOUNT);
				}else{
					$('#deposit-withdraw').find('.alert-info').text(reply.message).show();
				}
			});

			return false;
		});

		$('#add-transaction-form').on('submit',function(){
			var data = {};
			$(this).find('.form-control').each(function(i, el){
				data[el.name] = el.value;
			});
			data.portfolio_id = portfolios[currentPortfolio].ID;

			$.getJSON('./ajax/addTransaction.php',data,function(reply){
				console.log(reply);
			});

			return false;
		});
	},

	renderPortfolio = function(ind){
		$.getJSON('./ajax/getStockHoldings.php',{portfolio: portfolios[currentPortfolio].ID},function(reply){
			var template = _.template($('#template-portfolio').html()),
			list = [];

			for(var i=0; i<portfolios.length; i++){
				list.push(portfolios[i].NAME);
			}

			$('#content').html(template({
				name: portfolios[ind].NAME,
				portfolios: list,
				balance: portfolios[ind].CASH_ACCOUNT,
				stocks: reply
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
		});
	},

	stockDetails = function(symbol){
		$.getJSON('./ajax/quotehist.php',{symbol: symbol}, function(data){
			$('#stock-info').modal('show');
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

	loadSymbols = function(){
		$.getJSON('./ajax/getSymbols.php',function(reply){
			symbols = reply;
			$('#symbol-input').typeahead({name: 'stock-symbols', local: symbols});
			$('#symbol-input').on('typeahead:closed',function(){
				var sym = $(this).val(),
					ind = symbols.indexOf(sym);

				if(ind !== -1){
					$.getJSON('./ajax/quote.php',{symbol: symbols[ind]},function(reply){
						var close = parseFloat(reply.CLOSE,10),
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
	},

	login = function(data){
		$.getJSON('./ajax/login.php', data, function(reply){
			if(reply){
				LS.portfolio_full_name = reply.FULL_NAME;
				LS.portfolio_username = data.username;
				LS.portfolio_password = data.password;
				startSession();
			}else{
				addAlert('Login Failed');
				logout();
			}
		});
	},

	logout = function(){
		LS.portfolio_full_name = '';
		LS.portfolio_username = '';
		LS.portfolio_password = '';

		newUser();
	},

	addAlert = function(text){
		$('<div />').addClass('alert alert-warning')
			.html(text + ' <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>')
			.prependTo('#content');
	};

	return {
		init: init,
		stockDetails: stockDetails
	};
})();