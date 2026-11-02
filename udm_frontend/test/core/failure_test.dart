import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/core/network/failure.dart';

DioException _response(int status, Object data) {
  final options = RequestOptions(path: '/x');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  group('Failure.fromDio', () {
    test('a connection error is reported as offline', () {
      final failure = Failure.fromDio(
        DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'no route'),
      );

      expect(failure.kind, FailureKind.offline);
      expect(failure.isOffline, isTrue);
    });

    test('a timeout is distinguishable from a server fault', () {
      final failure = Failure.fromDio(
        DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/x'),
        ),
      );

      expect(failure.kind, FailureKind.timeout);
      expect(failure.isOffline, isTrue);
    });

    test('reads the API error envelope', () {
      final failure = Failure.fromDio(_response(400, {
        'detail': 'The submitted data is not valid.',
        'code': 'invalid',
        'status': 400,
        'errors': {'content_id': 'No devotional exists with this id.'},
      }));

      expect(failure.kind, FailureKind.rejected);
      expect(failure.message, 'The submitted data is not valid.');
      expect(failure.fieldErrors['content_id'], contains('No devotional'));
      expect(failure.statusCode, 400);
    });

    test('maps 401 and 404 to actionable kinds', () {
      expect(Failure.fromDio(_response(401, {'detail': 'Given token not valid'})).kind, FailureKind.unauthorized);
      expect(Failure.fromDio(_response(404, 'Not found')).kind, FailureKind.notFound);
    });

    test('a proxy page instead of JSON still yields a message', () {
      final failure = Failure.fromDio(_response(502, '<html>Bad Gateway</html>'));

      expect(failure.kind, FailureKind.serverUnavailable);
      expect(failure.message, 'The service is temporarily unavailable.');
    });
  });
}
