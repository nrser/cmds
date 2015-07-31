#!/usr/bin/env ruby

# ask some questions

qs = [
  "what is your name?",
  "what is your quest?",
  "what is you favorite color?",
]

qs.each do |q|
  puts q
  response = gets
end