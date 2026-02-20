import { describe, it, expect } from '@jest/globals';
import { cn } from '@/lib/utils';

describe('utils', () => {
  describe('cn', () => {
    it('should merge class names correctly', () => {
      const result = cn('class1', 'class2');
      expect(result).toContain('class1');
      expect(result).toContain('class2');
    });

    it('should handle conditional classes', () => {
      const result = cn('base', true && 'conditional');
      expect(result).toContain('base');
      expect(result).toContain('conditional');
    });

    it('should handle undefined and null', () => {
      const result = cn('base', undefined, null, 'valid');
      expect(result).toContain('base');
      expect(result).toContain('valid');
    });
  });
});
