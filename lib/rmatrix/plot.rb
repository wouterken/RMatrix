class RMatrix::Matrix
  def gplot(type: 'lines', series_names: [], xrange: nil, yrange: nil, title: '', ylabel: '', xlabel: '', style: nil)
    require 'gnuplot'
    require 'base64'
    output_file = Tempfile.new(['plt','.png']).path
    plot = nil
    Gnuplot.open do |gp|
      plot = Gnuplot::Plot.new( gp ) do |plot|

        plot.xrange "[#{xrange.begin}:#{xrange.end}]" if xrange
        plot.title  title
        plot.ylabel ylabel
        plot.xlabel xlabel
        plot.set("style", style) if style
        plot.terminal 'png size 1000,1000'

        x = (0..50).collect { |v| v.to_f }
        y = x.collect { |v| v ** 2 }

        plot.output(output_file)

        plot.data = self.each_row.map.with_index do |row, i|
          Gnuplot::DataSet.new(row.to_a) do |ds|
            ds.with = type
            ds.title = series_names[i] || ''
            yield ds if block_given?
          end
        end
      end
    end

    puts "\033]1337;File=inline=1:#{Base64.encode64(IO.read(output_file))}\a";
  end

  def gruff(title: '', type: 'Line', labels:{}, series_names: [], hide_legend: false, theme: Gruff::Themes::RAILS_KEYNOTE)
    require 'gruff'
    g = Gruff.const_get(type).new
    # g.theme = {
    #   :colors => ["#3366CC","#DC3912","#FF9900","#109618","#990099","#3B3EAC","#0099C6","#DD4477","#66AA00","#B82E2E","#316395","#994499","#22AA99","#AAAA11","#6633CC","#E67300","#8B0707","#329262","#5574A6","#3B3EAC"],
    #   :marker_color => '#dddddd',
    #   :font_color => 'black',
    #   :background_colors => ['white', '#acacac']
    #   # :background_image => File.expand_path(File.dirname(__FILE__) + "/../assets/backgrounds/43things.png")
    # }
    # g.hide_legend = true if hide_legend || series_names.empty? && self.rows.to_i > 10
    # g.title = title
    # g.labels = {}
    self.each_row.map.with_index do |row, i|
      series_name = (series_names[i] || i).to_s
      g.data series_name, row.to_a[0..5].map{|v| v.round(2)}
    end if self.rows
    fname = "/tmp/chrt-#{Random.rand(1000000...9999999)}.png"
    g.write(fname)
    puts "\033]1337;File=inline=1:#{Base64.encode64(g.to_blob)}\a";
  end

  def threed_gplot(pm3d: false)
    require 'gnuplot'
    output_file = Tempfile.new(['plt','.png']).path
    plot = nil
    Gnuplot.open do |gp|
      plot = Gnuplot::SPlot.new( gp ) do |plot|

        case IRuby::Kernel.instance
        when nil
          puts "Setting output"
          plot.terminal 'png'
          plot.output(output_file)
        end
        # see sin_wave.rb
        plot.pm3d if pm3d
        plot.hidden3d

        plot.data << Gnuplot::DataSet.new( self.to_a ) do |ds|
          ds.with = 'lines'
          ds.matrix = true
        end

      end
    end

    puts "\033]1337;File=inline=1:#{Base64.encode64(IO.read(output_file))}\a";
  end
end