import { Avatar } from '../ui/Avatar';

interface GroupAvatarProps {
  members?: string[];
  size?: 'sm' | 'md' | 'lg';
}

const outerSizes = {
  sm: 'h-8 w-8',
  md: 'h-10 w-10',
  lg: 'h-14 w-14',
};

const innerSizes = {
  sm: 'sm' as const,
  md: 'sm' as const,
  lg: 'sm' as const,
};

export function GroupAvatar({ members = [], size = 'md' }: GroupAvatarProps) {
  const display = members.slice(0, 4);

  return (
    <div className={`grid grid-cols-2 gap-0.5 overflow-hidden rounded-full ${outerSizes[size]}`}>
      {display.map((id) => (
        <Avatar key={id} name={id} size={innerSizes[size]} className="rounded-none" />
      ))}
      {display.length < 4 &&
        Array.from({ length: 4 - display.length }).map((_, i) => (
          <div key={`empty-${i}`} className="bg-gray-200" />
        ))}
    </div>
  );
}
