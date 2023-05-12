require 'csv'
require 'yaml'

csv = CSV.new(STDIN, headers: true)

categories = csv.group_by { |row| row['Main Category'] }.map do |category, accounts|
  {
    'name' => category,
    'items' => accounts.map do |row|
      case row[0]
      when 'Account'
        {
          'account' => row['Handle'],
          'type' => 'account',
          'summary' => row['Brief Description (3-5 words)'],
        }
      when 'Hashtag'
        {
          'hashtag' => row['Handle'],
          'type' => 'hashtag',
          'bio' => row['Description'],
          'summary' => row['Brief Description (3-5 words)'],
        }
      end
    end.to_a,
  }
end.to_a

puts categories.to_yaml
