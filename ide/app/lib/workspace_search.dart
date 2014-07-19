// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_search;

import 'workspace.dart';

import 'dart:async';

class WorkspaceSearchResultLine {
  File file;
  String line;
  int lineNumber;
  int position;
  int length;

  WorkspaceSearchResultLine(this.file, this.line, this.lineNumber,
      this.position, this.length);
}

class WorkspaceSearchResultItem {
  List<WorkspaceSearchResultLine> lines;
  File file;

  WorkspaceSearchResultItem(this.file, this.lines);
}

abstract class WorkspaceSearchDelegate {
  void workspaceSearchFile(WorkspaceSearch search, File file) {}
  void workspaceSearchUpdated(WorkspaceSearch search) {}
  void workspaceSearchFinished(WorkspaceSearch search) {}
}

class WorkspaceSearch {
  List<WorkspaceSearchResultItem> results;
  WorkspaceSearchDelegate delegate;
  bool _cancelled;

  WorkspaceSearch() {
    results = [];
  }

  void performSearch(Resource res, String token) {
    _performSearchOnResource(res, token).then((_) {
      if (!_cancelled) {
        delegate.workspaceSearchFinished(this);
      }
    });
  }

  void cancel() {
    _cancelled = true;
  }

  Future _performSearchOnResource(Resource res, String token) {
    if (res.isScmPrivate() || res.isDerived()) {
      return new Future.value();
    }

    if (res is Container) {
      return _performSearchOnContainer(res, token);
    } else {
      return _performSearchOnFile(res as File, token);
    }
  }

  Future _performSearchOnFile(File file, String token) {
    if (!_cancelled) {
      delegate.workspaceSearchFile(this, file);
    }

    if (_cancelled) {
      return new Future.error('interrupted');
    }

    return file.getContents().then((String content) {
      int currentIndex = 0;
      int lineNumber = 1;
      int linesNumbers = [];
      while (currentIndex < content.length) {
        int nextIndex = content.indexOf('\n', currentIndex);
        if (nextIndex == -1) {
          nextIndex = content.length;
        }

        String line = content.substring(currentIndex, nextIndex);
        int tokenPosition = line.indexOf(token);
        if (tokenPosition != -1) {
          linesNumbers.add(new WorkspaceSearchResultLine(file, line, lineNumber,
              currentIndex + tokenPosition, token.length));
        }
        currentIndex = nextIndex + 1;
        lineNumber ++;
      }
      if (linesNumbers.length > 0) {
        _addResult(file, linesNumbers);
      }
    });
  }

  Future _performSearchOnContainer(Container container, String token) {
    return Future.forEach(container.getChildren(), (Resource res) {
      return _performSearchOnResource(res, token);
    });
  }

  void _addResult(File file, List<WorkspaceSearchResultLine> lines) {
    WorkspaceSearchResultItem item =
        new WorkspaceSearchResultItem(file, lines);
    results.add(item);
    if (!_cancelled) {
      delegate.workspaceSearchUpdated(this);
    }
  }
}
