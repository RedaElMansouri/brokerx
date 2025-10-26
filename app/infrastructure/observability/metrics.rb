module Infrastructure
  module Observability
    class Metrics
      # Minimal thread-safe counters and histograms for Prometheus exposition
      @mutex = Mutex.new
      @counters = Hash.new { |h, k| h[k] = Hash.new(0) } # name => { labels_hash_string => value }
      @gauges = Hash.new { |h, k| h[k] = Hash.new(0) }
      @histograms = {} # name => { buckets: [..], counts: {labels_key => [..bucket_counts..]}, sum: {labels_key => float} }

      class << self
        def inc_counter(name, labels = {}, by: 1)
          key = labels_key(labels)
          @mutex.synchronize { @counters[name.to_s][key] += by }
        end

        def set_gauge(name, value, labels = {})
          key = labels_key(labels)
          @mutex.synchronize { @gauges[name.to_s][key] = value }
        end

        def define_histogram(name, buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10])
          @mutex.synchronize do
            @histograms[name.to_s] ||= { buckets: buckets.sort, counts: Hash.new { |h, k| h[k] = Array.new(buckets.size + 1, 0) }, sum: Hash.new(0.0) }
          end
        end

        def observe(name, value, labels = {})
          h = @histograms[name.to_s]
          return unless h
          key = labels_key(labels)
          @mutex.synchronize do
            idx = h[:buckets].index { |b| value <= b } || h[:buckets].size
            h[:counts][key][idx] += 1
            @histograms[name.to_s][:sum][key] += value
          end
        end

        def to_prometheus_text
          lines = []
          # Counters
          @counters.each do |name, series|
            series.each do |k, v|
              lines << format_line(name, 'counter', v, parse_labels_key(k))
            end
          end
          # Gauges
          @gauges.each do |name, series|
            series.each do |k, v|
              lines << format_line(name, 'gauge', v, parse_labels_key(k))
            end
          end
          # Histograms
          @histograms.each do |name, h|
            buckets = h[:buckets]
            h[:counts].each do |k, counts|
              labels = parse_labels_key(k)
              cumulative = 0
              counts.each_with_index do |count, i|
                cumulative += count
                le = (i < buckets.size) ? buckets[i] : '+Inf'
                lines << format_line("#{name}_bucket", 'histogram', cumulative, labels.merge(le: le))
              end
              sum = h[:sum][k]
              total = counts.sum
              lines << format_line("#{name}_sum", 'histogram', sum, labels)
              lines << format_line("#{name}_count", 'histogram', total, labels)
            end
          end
          lines.join("\n") + "\n"
        end

        private

        def labels_key(labels)
          # stable key for labels hash
          return '' if labels.nil? || labels.empty?
          labels.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}=#{v}" }.join(',')
        end

        def parse_labels_key(key)
          return {} if key.nil? || key.empty?
          key.split(',').map { |pair| k, v = pair.split('=', 2); [k.to_sym, v] }.to_h
        end

        def format_line(name, _type, value, labels)
          if labels && !labels.empty?
            label_str = '{' + labels.map { |k, v| %Q(#{k}="#{v}") }.join(',') + '}'
            "#{sanitize(name)}#{label_str} #{value}"
          else
            "#{sanitize(name)} #{value}"
          end
        end

        def sanitize(name)
          name.gsub(/[^a-zA-Z0-9_:]/, '_')
        end
      end
    end
  end
end
