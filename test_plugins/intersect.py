from ansible import errors

class TestModule(object):

  def tests(self):
    return {
      'intersect': self.is_intersect,
        }

  def is_intersect(self, _list1, _list2):
    """ Test if two lists have any common items """
    if not _list1:
      raise errors.AnsibleFilterError("First list cannot be empty for intersect test.")
    if not _list2:
      raise errors.AnsibleFilterError("Second list cannot be empty for intersect test.")
    if not isinstance(_list1, list):
      raise errors.AnsibleFilterError(
        "First argument for intersect test must be a list, but found data type: %s" % (type(_list1))
      )
    if not isinstance(_list2, list):
      raise errors.AnsibleFilterError(
        "Second argument for intersect test must be a list, but found data type: %s" % (type(_list2))
      )
    for item in _list1:
      if item in _list2:
        return True
    return False
