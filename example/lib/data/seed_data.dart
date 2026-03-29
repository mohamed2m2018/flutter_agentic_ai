class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final bool isFlashDeal;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    this.isFlashDeal = false,
  });
}

class Category {
  final String id;
  final String name;
  final String icon;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class SeedData {
  static const categories = [
    Category(id: 'c1', name: 'Electronics', icon: '💻'),
    Category(id: 'c2', name: 'Fashion', icon: '👕'),
    Category(id: 'c3', name: 'Home', icon: '🏠'),
    Category(id: 'c4', name: 'Food', icon: '🍔'),
  ];

  static const products = [
    Product(
      id: 'p1',
      name: 'Wireless Noise-Canceling Headphones',
      description: 'Premium over-ear headphones with 30 hr battery life.',
      price: 299.99,
      categoryId: 'c1',
      imageUrl: 'https://via.placeholder.com/300?text=Headphones',
      rating: 4.8,
      reviewsCount: 1240,
    ),
    Product(
      id: 'p2',
      name: 'Smartphone Pro Max',
      description: 'Latest flagship smartphone with amazing camera.',
      price: 1099.00,
      categoryId: 'c1',
      imageUrl: 'https://via.placeholder.com/300?text=Smartphone',
      rating: 4.9,
      reviewsCount: 8560,
      isFlashDeal: true,
    ),
    Product(
      id: 'p3',
      name: 'Cotton T-Shirt',
      description: '100% organic cotton basic t-shirt.',
      price: 19.99,
      categoryId: 'c2',
      imageUrl: 'https://via.placeholder.com/300?text=T-Shirt',
      rating: 4.5,
      reviewsCount: 320,
    ),
    Product(
      id: 'p4',
      name: 'Running Shoes',
      description: 'Lightweight breathable running shoes.',
      price: 89.99,
      categoryId: 'c2',
      imageUrl: 'https://via.placeholder.com/300?text=Shoes',
      rating: 4.6,
      reviewsCount: 412,
    ),
    Product(
      id: 'p5',
      name: 'Smart Coffee Maker',
      description: 'Brew coffee from your phone.',
      price: 149.00,
      categoryId: 'c3',
      imageUrl: 'https://via.placeholder.com/300?text=Coffee+Maker',
      rating: 4.3,
      reviewsCount: 156,
      isFlashDeal: true,
    ),
  ];
}
