Deezer =

	init: ->

		DZ.init(

			appId: dz_id
			channelUrl: dz_channel
			player: true

		)

	play_track: (stack, callback) ->

		@_search(0, stack, callback)

	_search: (index, stack, callback) ->

		DZ.api( '/search', q: "#{stack[index].artist} #{stack[index].title}", (response) =>

			if !response.data?[0]?.id?

				return @_search(index + 1, stack, callback)

			DZ.player.playTracks [response.data[0].id]

			callback stack[index]
			
		)

now.ready ->

	if !user
		return

	Deezer.init()

	$('.loading').fadeIn(300)

	now.user = user

	now.get_songs (count)->

		if count < 3

			$('.loading').delay(500).fadeOut(300, -> $(this).text('Err... it looks like you\'ve never listened to any music. Maybe try doing that first?').addClass('error').fadeIn())
			return

		$('.loading').fadeOut(300)
		$('.lobby').delay(300).fadeIn(300)

		now.backfill_users()

	now.new_user = (user) ->

		if $('.lobby .user[data-id="' + user.id + '"]').length isnt 0
			return

		taste = "#{user.taste[0]}, #{user.taste[1]} and #{user.taste[2]}"

		$('.lobby p.lead')
			.after('<div class="user row" data-id="' + user.id + '">
					 <div class="span1">
					  <img src="//graph.facebook.com/' + user.id + '/picture?type=large">
					 </div>
					 <div class="span11">
					  <h3>' + user.displayName + '</h3>
					  <p class="muted">seems to enjoy ' + taste + '</p>
					 </div>
					</div>')
			.parent().find('.user').slideDown(300)

		if $('.lobby .user').length >= 2
			$('.lobby p.lead').slideUp(300)

			if parseInt(now.user.id) is 600859899
				$('.lobby > a').fadeIn(300)

	now.get_lost = (user) ->

		$('.lobby .user[data-id="' + user.id + '"]').slideUp 300, -> $(this).remove()

		if $('.lobby .user').length - 1 < 2
			$('.lobby p.lead').slideDown(300)
			$('.lobby > a').fadeOut(300)

	$('.lobby > a').on('click', -> now.start())

	now.receive = (selection) ->

		$('.lobby').fadeOut(300)
		$('.playground').delay(300).fadeIn(300).find('.songs').empty()

		Deezer.play_track(selection, (correct) ->

			start = new Date()

			for song in selection

				$('<a href="#" id="' + song._id + '" data-url="' + song.url + '"><div class="fail"><strong>Nope, that\'s wrong.</strong> You thicko.</div><div class="body"><img src="' + song.image + '" class="pull-left"><img src="//graph.facebook.com/' + song.user_id + '/picture" class="pull-right"><span class="pull-right"><i class="icon-user"></i> ' + song.user + '</span><strong>' + song.title + '</strong><br />' + song.artist + '</div></a>').appendTo('.playground .songs')

			$('.songs').on('click', 'a', (event) ->

				event.preventDefault()

				id = $(this).attr('id')

				if id isnt correct._id
					$(this).find('.body').fadeOut(300)
					$(this).find('.fail').delay(300).fadeIn(300)
					$('.songs a:not(#' + id + ')').fadeTo(600, 0.3)
					setTimeout =>

						$(this).find('.fail').fadeOut(300)
						$(this).find('.body').delay(300).fadeIn(300)
						$('.songs a:not(#' + id + ')').fadeTo(300, 1)

					, 1500

				else
					end = new Date()
					now.win(correct, (end - start) / 1000)

				now.post_og song.url

			)

		)

	now.won = (user, correct, time) ->

		DZ.player.pause()

		$('.playground').fadeOut(300)
		$('.results').delay(300).fadeIn(300)

		$('.results p .user').html(user.displayName)
		$('.results p .time').html(time)
		$('.results p .title').html(correct.title)
		$('.results p .artist').html(correct.artist)

		$('.results img:last').attr('src', '//graph.facebook.com/' + user.id + '/picture?type=large')

		setTimeout ->

			$('.results').fadeOut(300)
			$('.lobby').delay(300).fadeIn(300)

		, 3000
