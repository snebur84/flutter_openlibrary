import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buscador de Livros OpenLibrary',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider(
        create: (context) => BookSearchCubit(),
        child: const BookSearchScreen(),
      ),
    );
  }
}

class Book {
  final String? title;
  final List<String>? authorName;
  final int? coverI;
  final int? firstPublishYear;

  Book({
    this.title,
    this.authorName,
    this.coverI,
    this.firstPublishYear,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json['title'] as String?,
      authorName: (json['author_name'] as List?)?.cast<String>(),
      coverI: json['cover_i'] as int?,
      firstPublishYear: json['first_publish_year'] as int?,
    );
  }

  String getCoverUrl({String size = 'M'}) {
    if (coverI != null) {
      return 'https://covers.openlibrary.org/b/id/$coverI-$size.jpg';
    }
    return 'https://via.placeholder.com/120x180?Text=Sem+Capa';
  }

  String get authors => authorName?.join(', ') ?? 'Autor não disponível';
}

// Estados do Cubit
sealed class BookSearchState {}

final class BookSearchInitial extends BookSearchState {}

final class BookSearchLoading extends BookSearchState {}

final class BookSearchLoaded extends BookSearchState {
  final List<Book> books;
  BookSearchLoaded(this.books);
}

final class BookSearchError extends BookSearchState {
  final String message;
  BookSearchError(this.message);
}

// Cubit
class BookSearchCubit extends Cubit<BookSearchState> {
  BookSearchCubit() : super(BookSearchInitial());

  Future<void> searchBooks(String query) async {
    if (query.isEmpty) {
      emit(BookSearchInitial());
      return;
    }
    emit(BookSearchLoading());
    final String apiUrl = 'https://openlibrary.org/search.json?q=$query';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Book> results = (data['docs'] as List?)
                ?.map((item) => Book.fromJson(item))
                .toList() ??
            [];
        emit(BookSearchLoaded(results));
      } else {
        emit(BookSearchError('Erro ao buscar livros. Código: ${response.statusCode}'));
      }
    } catch (e) {
      emit(BookSearchError('Erro de conexão: $e'));
    }
  }
}

class BookSearchScreen extends StatefulWidget {
  const BookSearchScreen({super.key});

  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookSearchCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscador de Livros'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Digite o título, autor ou assunto',
                    ),
                    onSubmitted: (value) {
                      cubit.searchBooks(value);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    cubit.searchBooks(_searchController.text);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    cubit.searchBooks(''); // Limpa a busca e emite estado inicial
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<BookSearchCubit, BookSearchState>(
              builder: (context, state) {
                if (state is BookSearchInitial) {
                  return const Center(child: Text('Digite algo para buscar livros!'));
                } else if (state is BookSearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is BookSearchLoaded) {
                  final books = state.books;
                  if (books.isEmpty) {
                    return const Center(child: Text('Nenhum livro encontrado.'));
                  }
                  return ListView.builder(
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final Book book = books[index];
                      final coverUrl = book.getCoverUrl();
                      final title = book.title ?? 'Título não disponível';
                      final author = book.authors;

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 80,
                                height: 120,
                                child: Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(child: Text('Sem Capa'));
                                  },
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text('Autor: $author'),
                                    if (book.firstPublishYear != null)
                                      Text('Publicado em: ${book.firstPublishYear}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is BookSearchError) {
                  return Center(child: Text('Ocorreu um erro: ${state.message}'));
                }
                return const SizedBox.shrink(); // fallback
              },
            ),
          ),
        ],
      ),
    );
  }
}