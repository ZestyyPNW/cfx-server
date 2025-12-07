import Logo from "/images/logo.png"

export const Watermark: React.FC = () => {
  return (
    <div className="absolute top-12 right-6">
      <img
        src={Logo}
        className="w-16 h-16"
      />
    </div>
  );
};
