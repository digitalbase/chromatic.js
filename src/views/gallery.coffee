_ = require '../lib/underscore-parts';
GalleryPhotoView = require './gallery_photo';

# Based on Óscar López implementation in Python (http://stackoverflow.com/a/7942946)
_linear_partition = (->
  _cache = {}

  return (seq, k) ->
    key = seq.join() + k
    return _cache[key] if _cache[key]

    n = seq.length

    return [] if k <= 0
    return seq.map((x) -> [x]) if k > n

    table = (0 for x in [0...k] for y in [0...n])
    solution = (0 for x in [0...k-1] for y in [0...n-1])
    table[i][0] = seq[i] + (if i then table[i-1][0] else 0) for i in [0...n]
    table[0][j] = seq[0] for j in [0...k]
    for i in [1...n]
      for j in [1...k]
        m = _.min(([_.max([table[x][j-1], table[i][0]-table[x][0]]), x] for x in [0...i]), (o) -> o[0])
        table[i][j] = m[0]
        solution[i-1][j-1] = m[1]

    n = n-1
    k = k-2
    ans = []
    while k >= 0 and n > 0
      ans = [seq[i] for i in [(solution[n-1][k]+1)...n+1]].concat ans
      n = solution[n-1][k]
      k = k-1

    _cache[key] = [seq[i] for i in [0...n+1]].concat ans
)()

_scrollbar_width = (->
  _cache = null
  return ->
    return _cache if _cache
    div = $("<div style=\"width:50px;height:50px;overflow:hidden;position:absolute;top:-200px;left:-200px;\"><div style=\"height:100px;\"></div></div>")
    $(document.body).append div
    w1 = $("div", div).innerWidth()
    div.css "overflow-y", "auto"
    w2 = $("div", div).innerWidth()
    $(div).remove()
    _cache = w1 - w2
)()

class GalleryView
  constructor: (el, photos, options = {}) ->
    if el[0] == document.body
      @el = $('<div class="chromatic-gallery-full"/>')
      $(el).append(@el)
    else
      @el = $(el).addClass('chromatic-gallery')
    @photos       = _.map photos, (p) -> if _.isObject(p) then p else {small: p}
    #@zoom_view    = new Chromatic.ZoomView(@photos, options)
    @photo_views  = _.map @photos, (photo) => new GalleryPhotoView(this, photo, options.photo || {})
    @ideal_height = parseInt(@el.children().first().css('height'))
    @viewport = $( (options || {}).viewport || @el)
    @forceFullWidth = Boolean(options.forceFullWidth || false)
    $(window).on 'resize', _.debounce(@layout, 100)
    window.matchMedia('print').addListener(@layout)
    @viewport.on 'scroll', _.throttle(@lazyLoad, 100)

    if (!!@photos[0] || !!@photos[0].aspect_ratio)
      @layout()
    else
      @calculateAspectRatios()

  calculateAspectRatios: =>
    layout = _.after @photos.length, @layout
    _.each @photo_views, (p) -> p.load(layout)

  lazyLoad: =>
    threshold = 1000
    viewport = {
      top: @viewport.scrollTop() - threshold
      bottom: (@viewport.height() || $(window).height()) + @viewport.scrollTop() + threshold
    }
    _.each @photo_views, (photo_view) =>
      if photo_view.is_visible(viewport)
        photo_view.load()
      else
        photo_view.unload()

  layout: =>
    # (1) Find appropriate number of rows by dividing the sum of ideal photo widths by the width of the viewport
    $(document.body).css('overflowY', 'scroll')
    viewport_width = @el[0].getBoundingClientRect().width - parseInt(@el.css('paddingLeft')) - parseInt(@el.css('paddingRight')) # @el.width() gives wrong rounding
    viewport_width = viewport_width - _scrollbar_width() if @el[0].offsetWidth > @el[0].scrollWidth # has overflow
    $(document.body).css('overflowY', 'auto')
    ideal_height   = @ideal_height || parseInt((@el.height() || $(window).height()) / 2)
    summed_width   = _.reduce @photos, ((sum, p) -> sum += p.aspect_ratio * ideal_height), 0
    rows           = Math.round(summed_width / viewport_width)

    # forceFullWidth support
    rows           = Math.max(rows, 1) if @forceFullWidth

    if rows < 1
      # (2a) Fallback to just standard size when just a few photos
      _.each @photos, (photo, i) => @photo_views[i].resize parseInt(ideal_height * photo.aspect_ratio), ideal_height
    else
      # (2b) Partition photos across rows using the aspect_ratio as weight
      weights = _.map @photos, (p) -> parseInt(p.aspect_ratio * 100) # weight must be an integer
      partition = _linear_partition(weights, rows)

      # (3) Iterate through partition
      offset = 0
      _.each partition, (row) =>
        row_photos = row.reduce ((buffer, weight, i) => buffer.concat([@photos[offset + i]])), []
        row_photo_views = row.reduce ((buffer, weight, i) => buffer.concat([@photo_views[offset + i]])), []

        row_margins = row_photo_views.map ((photo_view) -> photo_view.margins())
        row_summed_horizontal_margins = row_margins.reduce ((sum, { left, right }) -> sum += left + right ), 0
        row_summed_aspect_ratios = row_photos.reduce ((sum, photo) -> sum += photo.aspect_ratio), 0
        row_width = viewport_width - row_summed_horizontal_margins
        row_height = parseInt(row_width / row_summed_aspect_ratios)
        row_used_width = 0

        _.each row, (p, i) =>
          width = parseInt(row_width / row_summed_aspect_ratios * row_photos[i].aspect_ratio)
          width = row_width - row_used_width if i == row_photos.length - 1
          height = row_height
          row_photo_views[i].resize(width, height)
          row_used_width += width

        offset += row.length

    @lazyLoad()

module.exports = GalleryView
