require 'yaml'
require 'resume'
require 'fileutils'

include FileUtils
module Resume
# Serializes a resume to/from YAML
class Serializer

    attr_accessor :experience_prefix
    attr_accessor :education_prefix
    attr_accessor :references_prefix
    attr_accessor :samples_prefix
    attr_accessor :core_prefix
    attr_accessor :skills_prefix
    attr_accessor :core_to_use
    attr_accessor :filter_file

    def initialize
        @experience_prefix='experience'
        @education_prefix='education'
        @references_prefix='references'
        @samples_prefix='samples'
        @core_prefix='resume'
        @skills_prefix='skills'
    end

    # Loads the resume artifacts from the given directory
    def load(dir)
        if (!File.exists?(dir))
            raise "#{dir} doesn't exist"
        end

        resume = Resume.new
        cores = read_cores(dir,core_prefix)
        if (cores.size > 1)
            if (core_to_use)
                cores.each() { |core| resume.core = core if core.name == core_to_use }
            else
                raise "You must specify a core resume to use since there are #{cores.size} of them"
            end
        else
            resume.core = cores[0]
        end
        raise "#{core_to_use} didn't match any resumes" if !resume.core
        config_filename = "#{dir}/config_#{core_to_use}.yaml"
        config = File.open(config_filename) { |yf| YAML::load( yf ) } if File.exists?(config_filename)
        resume.skills = File.open( "#{dir}/#{skills_prefix}.yaml" ) { |yf| YAML::load( yf ) } if File.exists?("#{dir}/#{skills_prefix}.yaml")
        resume.experience = read(dir,experience_prefix)
        warn "No experience detected" if resume.experience.size == 0
        resume.education = read(dir,education_prefix)
        resume.references = read(dir,references_prefix)
        resume.samples = read(dir,samples_prefix)
        resume.experience.sort!.reverse!
        resume.education.sort!.reverse!
        resume.samples.sort!.reverse!
        resume.experience.each() do |xp|
            xp.positions.each() do |position|
                if (filter_file)
                    require filter_file
                    if (FILTER.respond_to? :filter_config=)
                        FILTER.filter_config=config
                    end
                    position.achievements = FILTER.filter_achievements(position.achievements)
                end
            end
            xp.positions.sort!.reverse!
        end
        return resume
    end

    def read(dir,base_name,allow_prefix_only=false)
        list = Array.new
        files = Dir.glob("#{dir}/#{base_name}_*.yaml")
        if (allow_prefix_only)
            prefix_only_name = "#{dir}/#{base_name}.yaml";
            files << prefix_only_name if File.exists? prefix_only_name
        end
        files.each do |file|
            list << File.open( file ) { |yf| YAML::load( yf ) }
        end
        list
    end

    def read_cores(dir,base_name)
        return read(dir,base_name,true)
    end

    # Stores the resume artifacts to the given directory.
    def store(dir,resume)
        if File.exists?(dir)
            rm(Dir.glob("#{dir}/*.yaml"))
        else
            mkdir(dir)
        end
        File.open("#{dir}/resume.yaml",'w') { |out| YAML::dump(resume.core,out) }
        dump(dir,"experience",resume.experience)
        dump(dir,"education",resume.education)
        dump(dir,"reference",resume.references)
        dump(dir,"samples",resume.samples)
        File.open("#{dir}/skills.yaml",'w') { |out| YAML::dump(resume.skills,out) }
    end

    def dump(dir,base_name,items)
        if (items && !items.empty?)
            count = 1
            items.each() do |item|
                filename = base_name + "_"
                if (item.respond_to? :name)
                    filename += item.name.gsub(/\//,"_").gsub(/\s/,"_")
                else
                    filename += count.to_s
                end
                filename += ".yaml"
                File.open("#{dir}/#{filename}",'w') { |out| YAML::dump(item,out) }
                count += 1
            end
        end
    end
end
end
