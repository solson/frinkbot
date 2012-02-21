require 'cinch'
require 'patron'
require 'nokogiri'
require 'cgi'

bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "onyx.ninthbit.net"
    c.nick     = "frink"
    c.channels = ["#programming", "#offtopic", "#bots"]
  end

  helpers do
    def sprunge(text)
      sess = Patron::Session.new
      sess.timeout = 10
      sess.base_url = "http://sprunge.us"
      sess.headers['User-Agent'] = 'frinkbot/1.0'

      r = sess.post("/", "sprunge=" + CGI.escape(text))
      r.body.strip
    rescue Patron::Error => e
      "A network error occurred (to sprunge): #{e.message}"
    end

    def frink(code)
      sess = Patron::Session.new
      sess.timeout = 10
      sess.base_url = "http://futureboy.us"
      sess.headers['User-Agent'] = 'frinkbot/1.0'

      r = sess.get("/fsp/frink.fsp?fromVal=" + CGI.escape("B := byte; b := bit; " + code))

      return "HTTP error code #{r.status} while executing command (#{r.url})" if r.status >= 400

      doc = Nokogiri::HTML(r.body)
      results_node = doc.xpath('//a[@name="results"]').first

      answer = if results_node.text == ""
        parent_text = results_node.parent.text.strip
        parent_text.start_with?("Syntax error") ? "Syntax error" : parent_text
      else
        results_node.text.strip
      end

      if answer.start_with?("Conformance error")
        parse_conformance_error(answer) + " | " + sprunge(answer)
      elsif answer.include?("\n")
        answer.split("\n").first + " | " + sprunge(answer)
      else
        answer
      end
    rescue Patron::Error => e
      "A network error occurred (to frink): #{e.message}"
    end

    def parse_conformance_error(text)
      left = text[/Left side is: (.+)/, 1]
      right = text[/Right side is: (.+)/, 1]
      "Conformance error: #{left} -> #{right}"
    end
  end

  on :message, /^#{Regexp.escape nick}\S*\s*(.+)$/ do |m, code|
    m.reply(frink(code), true)
  end
end

bot.start

