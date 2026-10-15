import '../domain/good_repository.dart';

// abstract interface class CommentedRepository {}
// class CommentedImpl implements GoodRepository {}

class UsesRepository {
  const UsesRepository(this.repository);

  final GoodRepository repository;
}
