# frozen_string_literal: true

RSpec.describe 'FetchUtil recipe extraction' do
  include_context 'extractor integration helpers'

  it 'classifies JSON-LD Recipe pages as recipes instead of lists' do
    html = fixture_contents(File.expand_path('../../fixtures/recipe_bbc_good_food_json_ld.html', __dir__))

    extract_from_url('https://www.bbcgoodfood.com/recipes/focaccia', html) do |payload|
      expect_content_type(payload, 'recipe')
      expect(payload['title']).to eq('Moonlit skillet bread')
      expect(payload['ingredients']).to include('500g cloud flour')
      expect(payload['instructions']).to include('Whisk the cloud flour, night-bloom yeast, and copper salt in a wide bowl.')
      expect(payload['markdown']).to include('## Ingredients')
      expect(payload['markdown']).to include('## Instructions')
      expect(payload['warnings']).not_to include('truncated_content')
      expect(payload['suspect']).to be(false)
    end
  end

  it 'flattens nested recipe instructions from food-blog schema' do
    html = fixture_contents(File.expand_path('../../fixtures/recipe_food_blog_nested_json_ld.html', __dir__))

    extract_from_url('https://minimalistbaker.com/1-bowl-vegan-gluten-free-vanilla-cake/', html) do |payload|
      expect_content_type(payload, 'recipe')
      expect(payload['ingredients']).to eq(
        [
          '1 cup almond milk',
          '1 tsp apple cider vinegar',
          '1 1/2 cups gluten-free flour blend',
          '3/4 cup cane sugar'
        ]
      )
      expect(payload['instructions']).to include('Preheat the oven and line an 8-inch cake pan.')
      expect(payload['instructions']).to include('Bake until the top springs back and a toothpick comes out clean.')
      expect(payload['warnings']).not_to include('truncated_content')
    end
  end

  it 'preserves every ingredient and instruction beyond the presentation thresholds' do
    html = fixture_contents(File.expand_path('../../fixtures/recipe_over_cap_json_ld.html', __dir__))

    extract_from_url('https://example.test/recipes/over-cap', html) do |payload|
      expect(payload['ingredients'].length).to eq(26)
      expect(payload['instructions'].length).to eq(21)
      expect(payload['markdown']).to include('Ingredient 26', 'Instruction 21')
    end
  end
end
