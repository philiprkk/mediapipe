// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <XCTest/XCTest.h>

#import "mediapipe/tasks/ios/common/sources/MPPCommon.h"
#import "mediapipe/tasks/ios/text/text_embedder/sources/MPPTextEmbedder.h"

static NSString *const kBertTextEmbedderModelName = @"mobilebert_embedding_with_metadata";
static NSString *const kRegexTextEmbedderModelName = @"regex_one_embedding_with_metadata";
static NSString *const kText1 = @"it's a charming and often affecting journey";
static NSString *const kText2 = @"what a great and fantastic trip";
static NSString *const kExpectedErrorDomain = @"com.google.mediapipe.tasks";
static const float kFloatDiffTolerance = 1e-4;
static const float kDoubleDiffTolerance = 1e-4;

#define AssertEqualErrors(error, expectedError)                                               \
  XCTAssertNotNil(error);                                                                     \
  XCTAssertEqualObjects(error.domain, expectedError.domain);                                  \
  XCTAssertEqual(error.code, expectedError.code);                                             \
  XCTAssertNotEqual(                                                                          \
      [error.localizedDescription rangeOfString:expectedError.localizedDescription].location, \
      NSNotFound)

#define AssertTextEmbedderResultHasOneEmbedding(textEmbedderResult) \
  XCTAssertNotNil(textEmbedderResult);                              \
  XCTAssertNotNil(textEmbedderResult.embeddingResult);              \
  XCTAssertEqual(textEmbedderResult.embeddingResult.embeddings.count, 1);

#define AssertEmbeddingIsFloat(embedding)    \
  XCTAssertNotNil(embedding.floatEmbedding); \
  XCTAssertNil(embedding.quantizedEmbedding);

#define AssertFloatEmbeddingHasExpectedValues(floatEmbedding, expectedLength, expectedFirstValue) \
  XCTAssertEqual(floatEmbedding.count, expectedLength);                                           \
  XCTAssertEqualWithAccuracy(floatEmbedding[0].floatValue, expectedFirstValue, kFloatDiffTolerance);

@interface MPPTextEmbedderTests : XCTestCase
@end

@implementation MPPTextEmbedderTests

- (NSString *)filePathWithName:(NSString *)fileName extension:(NSString *)extension {
  NSString *filePath = [[NSBundle bundleForClass:self.class] pathForResource:fileName
                                                                      ofType:extension];
  return filePath;
}

- (MPPTextEmbedder *)textEmbedderFromModelFileWithName:(NSString *)modelName {
  NSString *modelPath = [self filePathWithName:modelName extension:@"tflite"];

  NSError *error = nil;
  MPPTextEmbedder *textEmbedder = [[MPPTextEmbedder alloc] initWithModelPath:modelPath
                                                                       error:&error];

  XCTAssertNotNil(textEmbedder);

  return textEmbedder;
}

- (NSArray<NSNumber *> *)assertFloatEmbeddingResultsOfEmbedText:(NSString *)text
                                              usingTextEmbedder:(MPPTextEmbedder *)textEmbedder
                                                       hasCount:(NSUInteger)embeddingCount
                                                     firstValue:(float)firstValue {
  MPPTextEmbedderResult *embedderResult = [textEmbedder embedText:text error:nil];
  AssertTextEmbedderResultHasOneEmbedding(embedderResult);
  AssertEmbeddingIsFloat(embedderResult.embeddingResult.embeddings[0]);
  AssertFloatEmbeddingHasExpectedValues(embedderResult.embeddingResult.embeddings[0].floatEmbedding,
                                        embeddingCount, firstValue);
  return embedderResult.embeddingResult.embeddings[0];
}

- (void)testCreateTextEmbedderFailsWithMissingModelPath {
  NSString *modelPath = [self filePathWithName:@"" extension:@""];

  NSError *error = nil;
  MPPTextEmbedder *textEmbedder = [[MPPTextEmbedder alloc] initWithModelPath:modelPath
                                                                       error:&error];
  XCTAssertNil(textEmbedder);

  NSError *expectedError = [NSError
      errorWithDomain:kExpectedErrorDomain
                 code:MPPTasksErrorCodeInvalidArgumentError
             userInfo:@{
               NSLocalizedDescriptionKey :
                   @"INVALID_ARGUMENT: ExternalFile must specify at least one of 'file_content', "
                   @"'file_name', 'file_pointer_meta' or 'file_descriptor_meta'."
             }];
  AssertEqualErrors(error, expectedError);
}

- (void)testEmbedWithBertSucceeds {
  MPPTextEmbedder *textEmbedder =
      [self textEmbedderFromModelFileWithName:kBertTextEmbedderModelName];

  MPPEmbedding *embedding1 = [self assertFloatEmbeddingResultsOfEmbedText:kText1
                                                        usingTextEmbedder:textEmbedder
                                                                 hasCount:512
                                                               firstValue:20.057026f];

  MPPEmbedding *embedding2 = [self assertFloatEmbeddingResultsOfEmbedText:kText2
                                                        usingTextEmbedder:textEmbedder
                                                                 hasCount:512
                                                               firstValue:21.254150f];
  NSNumber *cosineSimilarity = [MPPTextEmbedder cosineSimilarityBetweenEmbedding1:embedding1
                                                                    andEmbedding2:embedding2
                                                                            error:nil];
  XCTAssertEqualWithAccuracy(cosineSimilarity.doubleValue, 0.96386, kDoubleDiffTolerance);
}

- (void)testEmbedWithRegexSucceeds {
  MPPTextEmbedder *textEmbedder =
      [self textEmbedderFromModelFileWithName:kRegexTextEmbedderModelName];

  MPPEmbedding *embedding1 = [self assertFloatEmbeddingResultsOfEmbedText:kText1
                                                        usingTextEmbedder:textEmbedder
                                                                 hasCount:16
                                                               firstValue:0.030935612f];

  MPPEmbedding *embedding2 = [self assertFloatEmbeddingResultsOfEmbedText:kText2
                                                        usingTextEmbedder:textEmbedder
                                                                 hasCount:16
                                                               firstValue:0.0312863f];

  NSNumber *cosineSimilarity = [MPPTextEmbedder cosineSimilarityBetweenEmbedding1:embedding1
                                                                    andEmbedding2:embedding2
                                                                            error:nil];
  XCTAssertEqualWithAccuracy(cosineSimilarity.doubleValue, 0.999937f, kDoubleDiffTolerance);
}

@end
