/* GENERATED from select.html (DISHES + CATS) by scratchpad mealdata.py — do not edit here.
   The delivered-day sheet reads the same menu the selector sells, so the two cannot drift. */
(function () {
const DISHES = {
  breakfast: [
    { n: 'Keto Cheese Pastry', kcal: 380, p: 16, c: 12, f: 29, r: '4.3', img: 'm-cheesepastry.jpg', ing: ['🧀 Cheese', '🌾 Almond flour', '🧈 Butter', '🥚 Egg', '🫓 Sesame seeds', '🌿 Za\u2019atar', '🥛 Greek yogurt', '🧂 Salt'] },
    { n: 'Oatmeal with Chocolate Chips', kcal: 410, p: 12, c: 58, f: 14, r: '4.3', img: 'm-oatmeal.jpg', ing: ['🌾 Oats', '🍫 Chocolate chips', '🥛 Milk', '🍌 Banana', '🥜 Peanut butter', 'Cinnamon', '🍯 Honey', '🧂 Salt'] },
    { n: 'Keto Olive Cheese Sandwich', kcal: 360, p: 18, c: 10, f: 27, r: '4.3', img: 'm-olivesand.jpg', ing: ['🫒 Olives', '🧀 Cheese', '🍞 Keto bread', '🥬 Lettuce', '🥒 Cucumber', '🧀 Cream cheese', '🌿 Oregano', '🍅 Sundried tomato'] },
    { n: 'Chocolate Pudding', kcal: 240, p: 6, c: 30, f: 11, r: '4.3', img: 'm-chocpudding.jpg', ing: ['🍫 Cacao', '🥛 Milk', '🌰 Chia seeds', '🍦 Whipped cream', '🫐 Berries', '🍫 Chocolate shavings', '🍯 Honey'] },
  ],
  lunch: [
    { n: 'Baked Chicken Fingers with Wedges', kcal: 480, p: 30, c: 22, f: 12, r: '4.3', img: 'm-fingers.jpg', ing: ['🍗 Chicken breast', '🌾 Panko crumbs', '🥔 Potato wedges', '🌶️ Spicy mayo', '🍅 Ketchup dip', 'Paprika', '🧄 Garlic powder', '🧂 Salt'] },
    { n: 'Chicken Machbous with tomato sauce', kcal: 465, p: 32, c: 48, f: 14, r: '4.3', img: 'm-machbous.jpg', ing: ['🍗 Chicken', '🍚 Rice', '🍅 Tomato sauce', '🌶️ Spicy', '🧅 Onion', '🧄 Garlic', '🍋 Dried lime', 'Cardamom', 'Cinnamon'] },
    { n: 'Thai Chicken Curry with Cube Potato', kcal: 440, p: 28, c: 41, f: 16, r: '4.3', img: 'm-thaicurry.jpg', ing: ['🍗 Chicken', '🥔 Cube potato', '🥥 Coconut milk', '🍛 Curry paste', '🌶️ Spicy', '🌿 Thai basil', '🍃 Lime leaves', '🐟 Fish sauce', '🍚 Rice'] },
    { n: 'Grilled Chicken with Garfelo Pasta', kcal: 452, p: 35, c: 44, f: 12, r: '4.3', img: 'm-garfelo.jpg', ing: ['🍗 Grilled chicken', '🍝 Garfelo pasta', '🍅 Tomato sauce', '🧀 Parmesan', '🍄 Mushrooms', '🫒 Olive oil', 'Black pepper', '🌿 Basil'] },
    { n: 'Chicken Pasta Salad', kcal: 445, p: 29, c: 42, f: 15, r: '4.3', img: 'm-pastasalad.jpg', ing: ['🍗 Chicken', '🍝 Pasta', '🥬 Rocca', '🫒 Olives', '🍅 Cherry tomato', '🧀 Feta', '🌽 Sweet corn', '🍋 Lemon dressing'] },
    { n: 'Yogurt Chicken Salad', kcal: 420, p: 34, c: 21, f: 20, r: '4.3', img: 'm-yogurtchicken.jpg', ing: ['🍗 Chicken', '🥛 Yogurt sauce', '🥒 Cucumber', '🧄 Garlic', '🥬 Lettuce', '🌰 Walnuts', '🌿 Mint', '🌿 Dill'] },
  ],
  dinner: [
    { n: 'Yogurt Chicken Salad', kcal: 420, p: 34, c: 21, f: 20, r: '4.3', img: 'm-yogurtchicken.jpg', ing: ['🍗 Chicken', '🥛 Yogurt sauce', '🥒 Cucumber', '🧄 Garlic', '🥬 Lettuce', '🌰 Walnuts', '🌿 Mint', '🌿 Dill'] },
    { n: 'Shrimp Salad with Dill', kcal: 380, p: 31, c: 14, f: 19, r: '4.3', img: 'm-shrimpdill.jpg', ing: ['🦐 Shrimp', '🥬 Lettuce', '🌿 Dill', '🫒 Olives', '🥑 Avocado', '🍅 Cherry tomato', '🥛 Yogurt dressing', '🍋 Lemon'] },
    { n: 'Chicken Pasta Salad', kcal: 445, p: 29, c: 42, f: 15, r: '4.3', img: 'm-pastasalad.jpg', ing: ['🍗 Chicken', '🍝 Pasta', '🥬 Rocca', '🫒 Olives', '🍅 Cherry tomato', '🧀 Feta', '🌽 Sweet corn', '🍋 Lemon dressing'] },
    { n: 'Thai Chicken Curry with Cube Potato', kcal: 440, p: 28, c: 41, f: 16, r: '4.3', img: 'm-thaicurry.jpg', ing: ['🍗 Chicken', '🥔 Cube potato', '🥥 Coconut milk', '🍛 Curry paste', '🌶️ Spicy', '🌿 Thai basil', '🍃 Lime leaves', '🐟 Fish sauce', '🍚 Rice'] },
    { n: 'Grilled Chicken with Garfelo Pasta', kcal: 452, p: 35, c: 44, f: 12, r: '4.3', img: 'm-garfelo.jpg', ing: ['🍗 Grilled chicken', '🍝 Garfelo pasta', '🍅 Tomato sauce', '🧀 Parmesan', '🍄 Mushrooms', '🫒 Olive oil', 'Black pepper', '🌿 Basil'] },
  ],
  snacks: [
    { n: 'Strawberry Rocca Salad with Feta', kcal: 210, p: 7, c: 16, f: 13, r: '4.3', img: 'm-rocca.jpg', ing: ['🥬 Rocca', '🍓 Strawberry', '🧀 Feta', '🌰 Walnuts', '🧅 Red onion', 'Balsamic glaze', '🌿 Mint', '🍯 Honey vinaigrette'] },
    { n: 'Keto Zoodles Salad', kcal: 180, p: 6, c: 9, f: 14, r: '4.3', img: 'm-zoodles.jpg', ing: ['🥒 Zucchini noodles', '🍅 Cherry tomato', '🫒 Olive oil', '🧄 Garlic', '🧀 Parmesan', '🌿 Basil pesto', '🌰 Pine nuts', '🌶️ Chili flakes'] },
    { n: 'Chocolate Dipped Pineapple', kcal: 190, p: 3, c: 32, f: 6, r: '4.3', img: 'm-chocpineapple.jpg', ing: ['🍍 Pineapple', '🍫 Dark chocolate', '🥥 Coconut flakes', '🌰 Almond crumbs', '🧂 Sea salt', '🌿 Mint'] },
    { n: 'Dark Chocolate Donut', kcal: 280, p: 6, c: 34, f: 14, r: '4.3', img: 'm-donut.jpg', ing: ['🍩 Keto dough', '🍫 Dark chocolate glaze', '🌰 Almond flour', '🥚 Egg', '🍫 Cacao nibs', 'Vanilla', '✨ Sprinkles'] },
    { n: 'Keto Cheese Pastry', kcal: 380, p: 16, c: 12, f: 29, r: '4.3', img: 'm-cheesepastry.jpg', ing: ['🧀 Cheese', '🌾 Almond flour', '🧈 Butter', '🥚 Egg', '🫓 Sesame seeds', '🌿 Za\u2019atar', '🥛 Greek yogurt', '🧂 Salt'] },
  ],
  dessert: [
    { n: 'Chocolate Raspberry', kcal: 230, p: 5, c: 26, f: 12, r: '4.3', img: 'm-chocraspberry.jpg', ing: ['🍫 Dark chocolate', '🍓 Raspberry', '🥛 Cream', '🥥 Coconut flakes', '🌰 Pistachio', '🍯 Honey'] },
    { n: 'Chocolate Pudding', kcal: 240, p: 6, c: 30, f: 11, r: '4.3', img: 'm-chocpudding.jpg', ing: ['🍫 Cacao', '🥛 Milk', '🌰 Chia seeds', '🍦 Whipped cream', '🫐 Berries', '🍫 Chocolate shavings', '🍯 Honey'] },
    { n: 'Dark Chocolate Donut', kcal: 280, p: 6, c: 34, f: 14, r: '4.3', img: 'm-donut.jpg', ing: ['🍩 Keto dough', '🍫 Dark chocolate glaze', '🌰 Almond flour', '🥚 Egg', '🍫 Cacao nibs', 'Vanilla', '✨ Sprinkles'] },
    { n: 'Chocolate Dipped Pineapple', kcal: 190, p: 3, c: 32, f: 6, r: '4.3', img: 'm-chocpineapple.jpg', ing: ['🍍 Pineapple', '🍫 Dark chocolate', '🥥 Coconut flakes', '🌰 Almond crumbs', '🧂 Sea salt', '🌿 Mint'] },
  ],
};
const CATS = [
  { id: 'breakfast', title: 'Breakfast', quota: 1 },
  { id: 'lunch', title: 'Lunch', quota: 2 },
  { id: 'dinner', title: 'Dinner', quota: 1 },
  { id: 'snacks', title: 'Snacks', quota: 1 },
  { id: 'dessert', title: 'Dessert', quota: 0 },
];
window.DS_MEALS = { DISHES: DISHES, CATS: CATS };
})();
