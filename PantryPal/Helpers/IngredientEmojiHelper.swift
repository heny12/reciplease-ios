//
//  IngredientEmojiHelper.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import Foundation

struct IngredientEmojiHelper {
    /// Maps an ingredient name to its corresponding emoji
    /// - Parameter ingredient: The ingredient to get an emoji for
    /// - Returns: An emoji string representing the ingredient, or "🥡" as default
    static func emojiForIngredient(_ ingredient: Ingredient) -> String {
        let name = ingredient.generalName.lowercased()
        
        // Comprehensive ingredient emoji mappings (no prepared foods or alcohol)
        let emojiMap: [String: String] = [
            // Fruits
            "apple": "🍎", "apples": "🍎",
            "banana": "🍌", "bananas": "🍌",
            "orange": "🍊", "oranges": "🍊",
            "strawberry": "🍓", "strawberries": "🍓",
            "grape": "🍇", "grapes": "🍇",
            "watermelon": "🍉",
            "pineapple": "🍍",
            "mango": "🥭", "mangoes": "🥭", "mangos": "🥭",
            "peach": "🍑", "peaches": "🍑",
            "cherry": "🍒", "cherries": "🍒",
            "lemon": "🍋", "lemons": "🍋",
            "lime": "🍋", "limes": "🍋",
            "avocado": "🥑", "avocados": "🥑",
            "tomato": "🍅", "tomatoes": "🍅",
            "blueberry": "🫐", "blueberries": "🫐",
            "raspberry": "🫐", "raspberries": "🫐",
            "blackberry": "🫐", "blackberries": "🫐",
            "cranberry": "🫐", "cranberries": "🫐",
            "kiwi": "🥝", "kiwifruit": "🥝",
            "coconut": "🥥", "coconuts": "🥥",
            "pomegranate": "🍎", "pomegranates": "🍎",
            "pear": "🍐", "pears": "🍐",
            "plum": "🍑", "plums": "🍑",
            "apricot": "🍑", "apricots": "🍑",
            "fig": "🍑", "figs": "🍑",
            "date": "🍑", "dates": "🍑",
            "grapefruit": "🍊", "grapefruits": "🍊",
            "tangerine": "🍊", "tangerines": "🍊",
            "clementine": "🍊", "clementines": "🍊",
            "mandarin": "🍊", "mandarins": "🍊",
            "dragon fruit": "🥝", "dragonfruit": "🥝",
            "passion fruit": "🥝", "passionfruit": "🥝",
            "papaya": "🥭", "papayas": "🥭",
            "guava": "🥭", "guavas": "🥭",
            "lychee": "🍒", "lychees": "🍒",
            "starfruit": "🍑", "star fruit": "🍑",
            "persimmon": "🍑", "persimmons": "🍑",
            
            // Vegetables
            "carrot": "🥕", "carrots": "🥕",
            "broccoli": "🥦",
            "lettuce": "🥬",
            "corn": "🌽",
            "bell pepper": "🫑", "bell peppers": "🫑",
            "cucumber": "🥒", "cucumbers": "🥒",
            "mushroom": "🍄", "mushrooms": "🍄",
            "onion": "🧅", "onions": "🧅",
            "garlic": "🧄",
            "potato": "🥔", "potatoes": "🥔",
            "eggplant": "🍆", "eggplants": "🍆", "aubergine": "🍆", "aubergines": "🍆",
            "spinach": "🥬",
            "celery": "🥬",
            "yam": "🍠", "yams": "🍠", "sweet potato": "🍠", "sweet potatoes": "🍠",
            "beet": "🫑", "beets": "🫑", "beetroot": "🫑",
            "radish": "🫑", "radishes": "🫑",
            "turnip": "🫑", "turnips": "🫑",
            "rutabaga": "🫑", "rutabagas": "🫑",
            "parsnip": "🥕", "parsnips": "🥕",
            "zucchini": "🥒", "zucchinis": "🥒", "courgette": "🥒", "courgettes": "🥒",
            "squash": "🥒", "squashes": "🥒", "butternut squash": "🥒", "acorn squash": "🥒",
            "pumpkin": "🎃", "pumpkins": "🎃",
            "cabbage": "🥬", "cabbages": "🥬",
            "kale": "🥬",
            "chard": "🥬", "swiss chard": "🥬",
            "bok choy": "🥬", "bok choi": "🥬", "pak choi": "🥬",
            "brussels sprout": "🥬", "brussels sprouts": "🥬", "brussel sprout": "🥬",
            "cauliflower": "🥦",
            "asparagus": "🥒", "asparaguses": "🥒",
            "green bean": "🫛", "green beans": "🫛", "string bean": "🫛", "string beans": "🫛",
            "snap pea": "🫛", "snap peas": "🫛", "snow pea": "🫛", "snow peas": "🫛",
            "pea": "🫛", "peas": "🫛",
            "bean": "🫘", "beans": "🫘", "black bean": "🫘", "black beans": "🫘",
            "kidney bean": "🫘", "kidney beans": "🫘", "pinto bean": "🫘", "pinto beans": "🫘",
            "chickpea": "🫘", "chickpeas": "🫘", "garbanzo bean": "🫘", "garbanzo beans": "🫘",
            "lentil": "🫘", "lentils": "🫘",
            "artichoke": "🥬", "artichokes": "🥬",
            "leek": "🧅", "leeks": "🧅",
            "scallion": "🧅", "scallions": "🧅", "green onion": "🧅", "green onions": "🧅", "spring onion": "🧅", "spring onions": "🧅",
            "shallot": "🧅", "shallots": "🧅",
            "fennel": "🥒", "fennels": "🥒",
            "okra": "🥒", "okras": "🥒",
            "jalapeño": "🌶️", "jalapeno": "🌶️", "jalapeños": "🌶️", "jalapenos": "🌶️",
            "serrano": "🌶️", "serranos": "🌶️",
            "habanero": "🌶️", "habaneros": "🌶️",
            "poblano": "🌶️", "poblanos": "🌶️",
            "anaheim": "🌶️", "anaheims": "🌶️",
            "cayenne": "🌶️",
            "chili pepper": "🌶️", "chili peppers": "🌶️", "chile pepper": "🌶️", "chile peppers": "🌶️",
            "chili": "🌶️", "chilli": "🌶️", "chillies": "🌶️",
            "red pepper": "🫑", "red peppers": "🫑",
            "green pepper": "🫑", "green peppers": "🫑",
            "yellow pepper": "🫑", "yellow peppers": "🫑",
            "orange pepper": "🫑", "orange peppers": "🫑",
            "romaine": "🥬", "romaine lettuce": "🥬",
            "arugula": "🥬", "rocket": "🥬",
            "watercress": "🥬",
            "endive": "🥬",
            "radicchio": "🥬",
            "collard green": "🥬", "collard greens": "🥬",
            "mustard green": "🥬", "mustard greens": "🥬",
            "dandelion green": "🥬", "dandelion greens": "🥬",
            "beet green": "🥬", "beet greens": "🥬",
            "daikon": "🫑", "daikons": "🫑",
            "jicama": "🫑", "jicamas": "🫑",
            "kohlrabi": "🥬", "kohlrabis": "🥬",
            "celeriac": "🥕", "celery root": "🥕",
            "sunchoke": "🥔", "sunchokes": "🥔", "jerusalem artichoke": "🥔",
            
            // Proteins
            "chicken": "🍗", "chicken breast": "🍗", "chicken thigh": "🍗", "chicken leg": "🍗", "chicken wing": "🍗", "chicken wings": "🍗",
            "beef": "🥩", "steak": "🥩", "ground beef": "🥩",
            "pork": "🥩", "pork chop": "🥩", "pork chops": "🥩", "pork tenderloin": "🥩",
            "lamb": "🥩", "lamb chop": "🥩", "lamb chops": "🥩",
            "turkey": "🦃", "turkey breast": "🦃",
            "duck": "🦆", "duck breast": "🦆",
            "fish": "🐟", "salmon": "🐟", "tuna": "🐟", "cod": "🐟", "halibut": "🐟",
            "trout": "🐟", "mackerel": "🐟", "sardine": "🐟", "sardines": "🐟",
            "anchovy": "🐟", "anchovies": "🐟", "tilapia": "🐟", "bass": "🐟",
            "shrimp": "🦐", "prawn": "🦐", "prawns": "🦐",
            "crab": "🦀", "crabs": "🦀", "crab meat": "🦀",
            "lobster": "🦞", "lobsters": "🦞",
            "scallop": "🦪", "scallops": "🦪",
            "mussel": "🦪", "mussels": "🦪",
            "clam": "🦪", "clams": "🦪",
            "oyster": "🦪", "oysters": "🦪",
            "octopus": "🐙", "octopuses": "🐙",
            "squid": "🦑", "squids": "🦑", "calamari": "🦑",
            "egg": "🥚", "eggs": "🥚",
            "bacon": "🥓",
            "ham": "🥓",
            "sausage": "🥓", "sausages": "🥓",
            "tofu": "🧈", "tofus": "🧈",
            "tempeh": "🧈", "tempehs": "🧈",
            "seitan": "🧈",
            
            // Dairy
            "milk": "🥛",
            "cheese": "🧀", "cheddar": "🧀", "mozzarella": "🧀", "parmesan": "🧀",
            "swiss cheese": "🧀", "gouda": "🧀", "brie": "🧀", "feta": "🧀",
            "goat cheese": "🧀", "cream cheese": "🧀",
            "butter": "🧈",
            "yogurt": "🥣", "yoghurt": "🥣", "greek yogurt": "🥣",
            "cream": "🥛", "heavy cream": "🥛", "whipping cream": "🥛", "sour cream": "🥛",
            "buttermilk": "🥛",
            "cottage cheese": "🧀",
            "ricotta": "🧀",
            "mascarpone": "🧀",
            
            // Grains & Bread
            "bread": "🍞", "white bread": "🍞", "wheat bread": "🍞", "sourdough": "🍞",
            "roll": "🍞", "rolls": "🍞", "sweet roll": "🍞", "sweet rolls": "🍞",
            "rice": "🍚", "white rice": "🍚", "brown rice": "🍚", "jasmine rice": "🍚", "basmati rice": "🍚",
            "wild rice": "🍚", "arborio rice": "🍚",
            "pasta": "🍝", "spaghetti": "🍝", "penne": "🍝", "fettuccine": "🍝",
            "linguine": "🍝", "macaroni": "🍝", "rigatoni": "🍝", "fusilli": "🍝",
            "noodle": "🍜", "noodles": "🍜", "ramen": "🍜", "udon": "🍜", "soba": "🍜",
            "flour": "🌾", "all purpose flour": "🌾", "all-purpose flour": "🌾",
            "wheat flour": "🌾", "bread flour": "🌾", "cake flour": "🌾",
            "oat": "🌾", "oats": "🌾", "rolled oats": "🌾", "steel cut oats": "🌾",
            "quinoa": "🌾", "quinoas": "🌾",
            "barley": "🌾", "barleys": "🌾",
            "bulgur": "🌾", "bulgurs": "🌾",
            "couscous": "🌾",
            "farro": "🌾", "farros": "🌾",
            "millet": "🌾", "millets": "🌾",
            "buckwheat": "🌾",
            "amaranth": "🌾", "amaranths": "🌾",
            "teff": "🌾",
            "cornmeal": "🌽", "polenta": "🌽",
            "grits": "🌽",
            "tortilla": "🍞", "tortillas": "🍞", "corn tortilla": "🍞", "flour tortilla": "🍞",
            "pita": "🍞", "pita bread": "🍞",
            "naan": "🍞",
            "bagel": "🥯", "bagels": "🥯",
            "croissant": "🥐", "croissants": "🥐",
            "biscuit": "🍞", "biscuits": "🍞",
            "cracker": "🍞", "crackers": "🍞",
            
            // Nuts & Seeds
            "nut": "🥜", "almond": "🥜", "almonds": "🥜",
            "peanut": "🥜", "peanuts": "🥜",
            "walnut": "🥜", "walnuts": "🥜",
            "pecan": "🥜", "pecans": "🥜",
            "cashew": "🥜", "cashews": "🥜",
            "pistachio": "🥜", "pistachios": "🥜",
            "hazelnut": "🥜", "hazelnuts": "🥜", "filbert": "🥜", "filberts": "🥜",
            "macadamia": "🥜", "macadamias": "🥜",
            "brazil nut": "🥜", "brazil nuts": "🥜",
            "pine nut": "🥜", "pine nuts": "🥜",
            "sunflower seed": "🌻", "sunflower seeds": "🌻",
            "pumpkin seed": "🌻", "pumpkin seeds": "🌻", "pepita": "🌻", "pepitas": "🌻",
            "sesame seed": "🌻", "sesame seeds": "🌻",
            "chia seed": "🌻", "chia seeds": "🌻",
            "flax seed": "🌻", "flax seeds": "🌻", "linseed": "🌻",
            "hemp seed": "🌻", "hemp seeds": "🌻",
            "poppy seed": "🌻", "poppy seeds": "🌻",
            
            // Beverages (non-alcoholic only)
            "coffee": "☕", "coffee bean": "☕", "coffee beans": "☕",
            "tea": "🍵", "green tea": "🍵", "black tea": "🍵", "herbal tea": "🍵",
            "juice": "🧃", "orange juice": "🧃", "apple juice": "🧃", "cranberry juice": "🧃",
            "water": "💧",
            "coconut water": "🥥",
            "almond milk": "🥛", "soy milk": "🥛", "oat milk": "🥛",
            "coconut milk": "🥥",
            
            // Spices & Condiments
            "salt": "🧂", "sea salt": "🧂", "kosher salt": "🧂", "table salt": "🧂",
            "pepper": "🌶️", "black pepper": "🌶️", "white pepper": "🌶️",
            "cayenne pepper": "🌶️",
            "paprika": "🌶️",
            "cumin": "🌶️",
            "coriander": "🌶️", "cilantro": "🌶️",
            "turmeric": "🌶️",
            "cinnamon": "🌶️",
            "nutmeg": "🌶️",
            "ginger": "🫚", "gingers": "🫚", "fresh ginger": "🫚",
            "chive": "🧅", "chives": "🧅",
            "basil": "🌿", "basils": "🌿",
            "oregano": "🌿", "oreganos": "🌿",
            "thyme": "🌿", "thymes": "🌿",
            "rosemary": "🌿", "rosemaries": "🌿",
            "sage": "🌿", "sages": "🌿",
            "parsley": "🌿", "parsleys": "🌿",
            "dill": "🌿", "dills": "🌿",
            "mint": "🌿", "mints": "🌿",
            "bay leaf": "🌿", "bay leaves": "🌿",
            "tarragon": "🌿", "tarragons": "🌿",
            "marjoram": "🌿", "marjorams": "🌿",
            "oil": "🫒", "olive oil": "🫒", "olive": "🫒", "olives": "🫒",
            "vegetable oil": "🫒", "canola oil": "🫒", "sunflower oil": "🫒",
            "sesame oil": "🫒", "coconut oil": "🥥", "avocado oil": "🥑",
            "vinegar": "🍶", "balsamic vinegar": "🍶", "apple cider vinegar": "🍶",
            "white vinegar": "🍶", "rice vinegar": "🍶",
            "honey": "🍯",
            "maple syrup": "🍯",
            "molasses": "🍯",
            "agave": "🍯", "agave nectar": "🍯",
            "sauce": "🍶", "soy sauce": "🍶", "worcestershire sauce": "🍶",
            "hot sauce": "🌶️", "sriracha": "🌶️", "tabasco": "🌶️",
            "ketchup": "🍶",
            "mustard": "🍶", "dijon mustard": "🍶", "yellow mustard": "🍶",
            "mayonnaise": "🍶", "mayo": "🍶",
            "tahini": "🍶",
            "miso": "🍶",
            "fish sauce": "🍶",
            "oyster sauce": "🍶",
            "hoisin sauce": "🍶",
            "teriyaki sauce": "🍶",
            "barbecue sauce": "🍶", "bbq sauce": "🍶",
            "salsa": "🍶",
            "pesto": "🌿",
            "chimichurri": "🌿",
            "curry paste": "🌶️", "red curry paste": "🌶️", "green curry paste": "🌶️",
            "vanilla": "🌿", "vanilla extract": "🌿", "vanilla bean": "🌿",
            "cocoa powder": "🍫", "cacao powder": "🍫",
            "chocolate": "🍫", "dark chocolate": "🍫", "milk chocolate": "🍫",
            "cereal": "🥣", "cereals": "🥣"
        ]
        
        // Check for exact match first
        if let emoji = emojiMap[name] {
            return emoji
        }
        
        // Check for partial matches
        for (key, emoji) in emojiMap {
            if name.contains(key) || key.contains(name) {
                return emoji
            }
        }
        
        // Default fallback
        return "🥡"
    }
    
    /// Maps an ingredient name string to its corresponding emoji
    /// - Parameter ingredientName: The name of the ingredient
    /// - Returns: An emoji string representing the ingredient, or "🥡" as default
    static func emojiForIngredientName(_ ingredientName: String) -> String {
        let lowercased = ingredientName.lowercased()
        
        // Use the same mapping logic but with a temporary ingredient
        let tempIngredient = Ingredient(generalName: lowercased, quantity: "")
        return emojiForIngredient(tempIngredient)
    }
}
